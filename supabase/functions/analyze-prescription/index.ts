import { createClient } from "npm:@supabase/supabase-js@2";

// ============================================================================
// PharmaLens - Prescription Analysis Edge Function
// ============================================================================
//
// Security architecture:
//
// Flutter
//   ↓ authenticated Supabase anonymous user
// Edge Function
//   ↓ rate limit
// Gemini
//   ↓ transcription JSON only
// Flutter verification engine
//   ↓
// Supabase medicine database
//
// IMPORTANT:
// Gemini is ONLY used to transcribe the prescription.
// It must NOT verify medicines, diagnose, recommend substitutions,
// or generate clinical medicine information.
// ============================================================================

const FUNCTION_NAME =
  "analyze-prescription";

const MAX_IMAGE_BYTES =
  10 * 1024 * 1024;

const MAX_OCR_CHARACTERS =
  10000;

const MAX_DOCTOR_CONTEXT_CHARACTERS =
  2000;

const MAX_BASE64_CHARACTERS =
  15 * 1024 * 1024;

const HOURLY_REQUEST_LIMIT =
  20;

const GEMINI_TIMEOUT_MS =
  85000;

// ============================================================================
// CORS
// ============================================================================

const corsHeaders: Record<
  string,
  string
> = {
  "Access-Control-Allow-Origin":
    "*",

  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",

  "Access-Control-Allow-Methods":
    "POST, OPTIONS",
};

// ============================================================================
// Helpers
// ============================================================================

function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,

      headers: {
        ...corsHeaders,

        "Content-Type":
          "application/json; charset=utf-8",

        "Cache-Control":
          "no-store, max-age=0",
      },
    },
  );
}

function env(
  name: string,
): string {
  return (
    Deno.env.get(name)?.trim() ??
    ""
  );
}

function requiredEnv(
  name: string,
): string {
  const value =
    env(name);

  if (!value) {
    throw new Error(
      `Missing server environment variable: ${name}`,
    );
  }

  return value;
}

function cleanString(
  value: unknown,
  maximumLength = 1000,
): string {
  if (
    typeof value !==
    "string"
  ) {
    return "";
  }

  const cleaned =
    value
      .replace(/\s+/g, " ")
      .trim();

  if (
    cleaned.length <=
    maximumLength
  ) {
    return cleaned;
  }

  return cleaned.substring(
    0,
    maximumLength,
  );
}

function cleanMultilineString(
  value: unknown,
  maximumLength = 10000,
): string {
  if (
    typeof value !==
    "string"
  ) {
    return "";
  }

  const cleaned =
    value
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .trim();

  if (
    cleaned.length <=
    maximumLength
  ) {
    return cleaned;
  }

  return cleaned.substring(
    0,
    maximumLength,
  );
}

function cleanStringList(
  value: unknown,
  maximumItems = 8,
): string[] {
  if (
    !Array.isArray(value)
  ) {
    return [];
  }

  const output:
    string[] =
    [];

  const seen =
    new Set<string>();

  for (
    const rawValue of value
  ) {
    const item =
      cleanString(
        rawValue,
        500,
      );

    if (!item) {
      continue;
    }

    const key =
      item.toLowerCase();

    if (
      seen.has(key)
    ) {
      continue;
    }

    seen.add(key);

    output.push(item);

    if (
      output.length >=
      maximumItems
    ) {
      break;
    }
  }

  return output;
}

function normalizeResponseLanguage(
  value: unknown,
): "Arabic" | "English" {
  const normalized =
    cleanString(
      value,
      50,
    ).toLowerCase();

  if (
    normalized === "ar" ||
    normalized === "arabic"
  ) {
    return "Arabic";
  }

  return "English";
}

function supportedMimeType(
  value: string,
): boolean {
  const allowed =
    new Set<string>([
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/webp",
      "image/heic",
      "image/heif",
    ]);

  return allowed.has(
    value.toLowerCase(),
  );
}

function approximateBase64Bytes(
  base64: string,
): number {
  if (!base64) {
    return 0;
  }

  let padding =
    0;

  if (
    base64.endsWith("==")
  ) {
    padding =
      2;
  } else if (
    base64.endsWith("=")
  ) {
    padding =
      1;
  }

  return Math.max(
    0,
    Math.floor(
      (base64.length * 3) /
        4,
    ) - padding,
  );
}

function safeBoolean(
  value: unknown,
): boolean {
  return value === true;
}

// ============================================================================
// Supabase clients
// ============================================================================

function createServiceRoleClient() {
  const supabaseUrl =
    requiredEnv(
      "SUPABASE_URL",
    );

  const serviceRoleKey =
    requiredEnv(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

  return createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        persistSession:
          false,

        autoRefreshToken:
          false,

        detectSessionInUrl:
          false,
      },
    },
  );
}

function createUserAuthClient(
  authorization: string,
) {
  const supabaseUrl =
    requiredEnv(
      "SUPABASE_URL",
    );

  const publicKey =
    env(
      "SUPABASE_ANON_KEY",
    ) ||
    env(
      "SUPABASE_PUBLISHABLE_KEY",
    );

  if (!publicKey) {
    throw new Error(
      "Missing Supabase public key.",
    );
  }

  return createClient(
    supabaseUrl,
    publicKey,
    {
      auth: {
        persistSession:
          false,

        autoRefreshToken:
          false,

        detectSessionInUrl:
          false,
      },

      global: {
        headers: {
          Authorization:
            authorization,
        },
      },
    },
  );
}

// ============================================================================
// Authentication
// ============================================================================

class UnauthorizedError
  extends Error {}

async function authenticatedUserId(
  request: Request,
): Promise<string> {
  const authorization =
    request.headers.get(
      "Authorization",
    )?.trim() ??
    "";

  if (
    !authorization
      .toLowerCase()
      .startsWith(
        "bearer ",
      )
  ) {
    throw new UnauthorizedError(
      "Missing authorization.",
    );
  }

  const token =
    authorization
      .substring(
        "Bearer ".length,
      )
      .trim();

  if (!token) {
    throw new UnauthorizedError(
      "Missing access token.",
    );
  }

  const authClient =
    createUserAuthClient(
      authorization,
    );

  const {
    data,
    error,
  } =
    await authClient.auth
      .getUser(
        token,
      );

  if (
    error ||
    !data.user
  ) {
    console.warn(
      `[${FUNCTION_NAME}] invalid authentication token`,
    );

    throw new UnauthorizedError(
      "Invalid session.",
    );
  }

  const userId =
    data.user.id.trim();

  if (!userId) {
    throw new UnauthorizedError(
      "Missing user ID.",
    );
  }

  return userId;
}

// ============================================================================
// Rate limiting
// ============================================================================

type QuotaResult = {
  allowed: boolean;
  requestCount: number;
  resetAt: string;
};

async function consumeQuota(
  userId: string,
): Promise<QuotaResult> {
  const admin =
    createServiceRoleClient();

  const {
    data,
    error,
  } =
    await admin.rpc(
      "consume_ai_prescription_quota_v1",
      {
        p_user_id:
          userId,

        p_hourly_limit:
          HOURLY_REQUEST_LIMIT,
      },
    );

  if (error) {
    console.error(
      `[${FUNCTION_NAME}] quota RPC failed`,
      error.code,
    );

    throw new Error(
      "Quota service unavailable.",
    );
  }

  let row:
    Record<string, unknown> |
    null =
    null;

  if (
    Array.isArray(data) &&
    data.length > 0 &&
    typeof data[0] ===
      "object" &&
    data[0] !== null
  ) {
    row =
      data[0] as Record<
        string,
        unknown
      >;
  } else if (
    typeof data ===
      "object" &&
    data !== null
  ) {
    row =
      data as Record<
        string,
        unknown
      >;
  }

  if (!row) {
    throw new Error(
      "Invalid quota response.",
    );
  }

  return {
    allowed:
      row["allowed"] ===
      true,

    requestCount:
      Number(
        row[
          "request_count"
        ] ?? 0,
      ),

    resetAt:
      String(
        row["reset_at"] ??
        "",
      ),
  };
}

// ============================================================================
// Gemini configuration
// ============================================================================

function geminiApiKeys():
  string[] {
  const keys:
    string[] =
    [];

  const multiple =
    env(
      "GEMINI_API_KEYS",
    );

  if (multiple) {
    keys.push(
      ...multiple
        .split(",")
        .map(
          (
            value,
          ) =>
            value.trim(),
        )
        .filter(Boolean),
    );
  }

  const single =
    env(
      "GEMINI_API_KEY",
    );

  if (single) {
    keys.push(single);
  }

  return [
    ...new Set(keys),
  ];
}

function geminiModels():
  string[] {
  const models:
    string[] =
    [];

  const multiple =
    env(
      "GEMINI_MODELS",
    );

  if (multiple) {
    models.push(
      ...multiple
        .split(",")
        .map(
          (
            value,
          ) =>
            value.trim(),
        )
        .filter(Boolean),
    );
  }

  const single =
    env(
      "GEMINI_MODEL",
    );

  if (single) {
    models.push(single);
  }

  /*
   * We deliberately do NOT hardcode a fallback model.
   *
   * The model should be controlled from Supabase secrets so changing
   * providers/models does not require publishing a new Flutter version.
   */
  return [
    ...new Set(models),
  ];
}

// ============================================================================
// Gemini response schema
// ============================================================================

function transcriptionSchema() {
  return {
    type:
      "OBJECT",

    properties: {
      detectedDoctorName: {
        type:
          "STRING",
      },

      detectedSpecialty: {
        type:
          "STRING",
      },

      detectedPatientProblem: {
        type:
          "STRING",
      },

      rawInterpretation: {
        type:
          "STRING",
      },

      suggestions: {
        type:
          "ARRAY",

        items: {
          type:
            "OBJECT",

          properties: {
            identificationStatus: {
              type:
                "STRING",

              enum: [
                "exact_medicine",
                "possible_medicine",
                "category_only",
                "unreadable",
              ],
            },

            exactWrittenText: {
              type:
                "STRING",
            },

            writtenFragment: {
              type:
                "STRING",
            },

            medicineCategory: {
              type:
                "STRING",
            },

            name: {
              type:
                "STRING",
            },

            genericName: {
              type:
                "STRING",
            },

            strength: {
              type:
                "STRING",
            },

            form: {
              type:
                "STRING",
            },

            dose: {
              type:
                "STRING",
            },

            frequency: {
              type:
                "STRING",
            },

            duration: {
              type:
                "STRING",
            },

            writtenInstructions: {
              type:
                "STRING",
            },

            route: {
              type:
                "STRING",

              enum: [
                "ORAL",
                "RECTAL",
                "OPHTHALMIC",
                "OTIC",
                "TOPICAL",
                "IM",
                "IV",
                "INHALATION",
                "NASAL",
                "SUBLINGUAL",
                "TRANSDERMAL",
                "VAGINAL",
                "UNKNOWN",
              ],
            },

            routeConfidence: {
              type:
                "STRING",

              enum: [
                "high",
                "medium",
                "low",
              ],
            },

            routeEvidence: {
              type:
                "STRING",
            },

            routeExplicitlyWritten: {
              type:
                "BOOLEAN",
            },

            confidence: {
              type:
                "STRING",

              enum: [
                "high",
                "medium",
                "low",
              ],
            },

            reasons: {
              type:
                "ARRAY",

              items: {
                type:
                  "STRING",
              },
            },

            warnings: {
              type:
                "ARRAY",

              items: {
                type:
                  "STRING",
              },
            },

            requiresDoctorConfirmation: {
              type:
                "BOOLEAN",
            },
          },

          required: [
            "identificationStatus",
            "exactWrittenText",
            "writtenFragment",
            "medicineCategory",
            "name",
            "genericName",
            "strength",
            "form",
            "dose",
            "frequency",
            "duration",
            "writtenInstructions",
            "route",
            "routeConfidence",
            "routeEvidence",
            "routeExplicitlyWritten",
            "confidence",
            "reasons",
            "warnings",
            "requiresDoctorConfirmation",
          ],
        },
      },

      generalWarnings: {
        type:
          "ARRAY",

        items: {
          type:
            "STRING",
        },
      },
    },

    required: [
      "detectedDoctorName",
      "detectedSpecialty",
      "detectedPatientProblem",
      "rawInterpretation",
      "suggestions",
      "generalWarnings",
    ],
  };
}

// ============================================================================
// Prescription prompt
// ============================================================================

function buildPrimaryPrompt({
  responseLanguage,
  doctorContext,
  ocrText,
}: {
  responseLanguage:
    "Arabic" | "English";

  doctorContext:
    string;

  ocrText:
    string;
}): string {
  return `
You are the prescription transcription component of PharmaLens.

REQUESTED OUTPUT LANGUAGE:
${responseLanguage}

YOUR ONLY JOB:

Read the supplied prescription image and transcribe visible medication orders.

You are NOT the medicine verification engine.

You are NOT a clinical decision system.

STRICT RULES:

1. The image is the primary evidence.

2. OCR text is secondary evidence only.

3. Doctor context is weak supporting metadata only.

4. Never infer a medicine from:
   - doctor specialty
   - diagnosis
   - patient problem
   - common prescribing habits

5. Never invent:
   - medicine brand
   - generic ingredient
   - strength
   - dosage form
   - route
   - dose
   - frequency
   - duration

6. Never:
   - diagnose
   - recommend treatment
   - recommend a substitution
   - approve dispensing
   - claim a medicine is verified
   - generate indications
   - generate side effects
   - generate interactions
   - generate contraindications
   - generate pregnancy advice
   - generate clinical red flags

7. If something is uncertain, preserve the uncertainty.

IDENTIFICATION STATUS:

exact_medicine

Use only when the visible medicine name can be transcribed clearly enough
to preserve its written identity.

possible_medicine

Use when a medicine-name fragment appears visible but some characters
remain uncertain.

category_only

Use when only a medication category or dosage-form instruction is visible,
without a safely readable medicine identity.

unreadable

Use when a medication line exists but cannot be transcribed safely.

FIELD RULES:

exactWrittenText:

Preserve the complete readable medication line as closely as possible.

Do not rewrite it into a different medicine.

writtenFragment:

Preserve the visible medicine-name fragment.

name:

Clean spelling only when the visible characters clearly support it.

Do not expand abbreviations into another medicine.

genericName:

MUST be empty unless the generic ingredient itself is visibly written
on the prescription.

strength:

Only extract when visibly written.

If strength is absent or unreadable, return an empty string.

form:

Extract dosage form when visibly written.

Recognize common prescription abbreviations:

tab
tabs
tablet
tablets
→ Tablet

cap
caps
capsule
capsules
→ Capsule

syr
syp
syrup
→ Syrup

susp
suspension
→ Suspension

amp
ampoule
ampule
vial
inj
injection
→ Injection

cream
→ Cream

oint
ointment
→ Ointment

gel
→ Gel

drops
drop
→ Drops

supp
suppository
→ Suppository

spray
→ Spray

inhaler
→ Inhaler

IMPORTANT VARIANT EXAMPLE:

If the visible prescription says:

Frenaler Cort tab

return approximately:

exactWrittenText:
Frenaler Cort tab

writtenFragment:
Frenaler Cort

name:
Frenaler Cort

form:
Tablet

Do NOT convert this to Syrup.

IMPORTANT STRENGTH EXAMPLE:

If only this is visible:

Funzol

and no strength is readable:

name:
Funzol

strength:
EMPTY STRING

Never invent:
50 mg
150 mg
or any other strength.

ROUTE RULES:

Tablet/capsule/syrup/suspension:
route may be ORAL.

This does NOT mean routeExplicitlyWritten is true.

PO / oral:
ORAL

PR / rectal:
RECTAL

eye drops / ophthalmic:
OPHTHALMIC

ear drops / otic:
OTIC

cream / ointment / gel / topical:
TOPICAL unless clearly ophthalmic or otic.

IM / intramuscular:
IM

IV / intravenous:
IV

Injection with no explicit IM or IV:
UNKNOWN

Inhaled / inhaler:
INHALATION

Nasal:
NASAL

Sublingual:
SUBLINGUAL

Transdermal:
TRANSDERMAL

Vaginal:
VAGINAL

If uncertain:
UNKNOWN

routeExplicitlyWritten:

TRUE only when route wording itself is visibly present.

A dosage form may support route classification, but it does not mean
the route itself was explicitly written.

CONFIDENCE:

Confidence means transcription confidence only.

It does NOT mean:
- medicine verification confidence
- medication safety
- dispensing approval

WARNINGS:

Warnings may describe transcription uncertainty only.

Examples:
- "Strength is not clearly readable."
- "Medicine name contains uncertain handwriting."
- "Route is not explicitly written."

Do NOT generate clinical medicine warnings.

PATIENT PROBLEM:

detectedPatientProblem must remain empty unless a problem/diagnosis is
explicitly written and readable on the prescription.

Even when readable, do NOT use it to identify medicine.

DOCTOR CONTEXT:

${doctorContext || "(none)"}

SECONDARY OCR TEXT:

${ocrText || "(none)"}

Return structured JSON only.
`;
}

function buildRecoveryPrompt({
  responseLanguage,
  ocrText,
}: {
  responseLanguage:
    "Arabic" | "English";

  ocrText:
    string;
}): string {
  return `
Re-read the prescription image.

This is a strict transcription task.

Output language:
${responseLanguage}

Return every visible medication line that can be detected.

Never diagnose.

Never provide medicine indications.

Never provide side effects.

Never provide interactions.

Never recommend alternatives.

Never approve a medicine.

Never invent:
- medicine identity
- generic ingredient
- strength
- dosage form
- route

Preserve exactWrittenText.

Preserve the visible medicine-name fragment in writtenFragment.

If the visible text says:

Frenaler Cort tab

the dosage form is Tablet.

Do not return Syrup unless Syrup is visibly written.

If only:

Funzol

is readable and strength is absent:

strength must be an empty string.

Injection without explicit IM or IV:

route = UNKNOWN.

If a medication line cannot be read safely:

identificationStatus = unreadable.

Secondary OCR:

${ocrText || "(none)"}

Return structured JSON only.
`;
}

// ============================================================================
// Gemini request
// ============================================================================

class GeminiRequestError
  extends Error {
  constructor(
    public readonly status:
      number,

    public readonly retryable:
      boolean,

    message:
      string,
  ) {
    super(message);
  }
}

async function callGemini({
  apiKey,
  model,
  imageBase64,
  imageMimeType,
  prompt,
  maxOutputTokens,
}: {
  apiKey:
    string;

  model:
    string;

  imageBase64:
    string;

  imageMimeType:
    string;

  prompt:
    string;

  maxOutputTokens:
    number;
}): Promise<
  Record<string, unknown>
> {
  const controller =
    new AbortController();

  const timeout =
    setTimeout(
      () => {
        controller.abort();
      },
      GEMINI_TIMEOUT_MS,
    );

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;

    const response =
      await fetch(
        url,
        {
          method:
            "POST",

          signal:
            controller.signal,

          headers: {
            "Content-Type":
              "application/json",

            "x-goog-api-key":
              apiKey,
          },

          body:
            JSON.stringify({
              contents: [
                {
                  role:
                    "user",

                  parts: [
                    {
                      inlineData: {
                        mimeType:
                          imageMimeType,

                        data:
                          imageBase64,
                      },
                    },

                    {
                      text:
                        prompt,
                    },
                  ],
                },
              ],

              generationConfig: {
                temperature:
                  0,

                candidateCount:
                  1,

                maxOutputTokens:
                  maxOutputTokens,

                responseMimeType:
                  "application/json",

                responseSchema:
                  transcriptionSchema(),
              },
            }),
        },
      );

    if (!response.ok) {
      const body =
        (
          await response.text()
        ).slice(
          0,
          600,
        );

      console.error(
        `[${FUNCTION_NAME}] Gemini HTTP ${response.status}: ${body}`,
      );

      const retryable =
        response.status ===
          408 ||
        response.status ===
          429 ||
        response.status >=
          500;

      throw new GeminiRequestError(
        response.status,
        retryable,
        "Gemini request failed.",
      );
    }

    const decoded:
      unknown =
      await response.json();

    return extractGeminiJson(
      decoded,
    );
  } catch (error) {
    if (
      error instanceof
      GeminiRequestError
    ) {
      throw error;
    }

    if (
      error instanceof
        DOMException &&
      error.name ===
        "AbortError"
    ) {
      throw new GeminiRequestError(
        408,
        true,
        "Gemini request timed out.",
      );
    }

    throw error;
  } finally {
    clearTimeout(
      timeout,
    );
  }
}

// ============================================================================
// Gemini response extraction
// ============================================================================

function extractGeminiJson(
  response: unknown,
): Record<string, unknown> {
  if (
    typeof response !==
      "object" ||
    response ===
      null
  ) {
    throw new Error(
      "Invalid Gemini response.",
    );
  }

  const root =
    response as Record<
      string,
      unknown
    >;

  const candidates =
    root["candidates"];

  if (
    !Array.isArray(
      candidates,
    ) ||
    candidates.length ===
      0
  ) {
    throw new Error(
      "Gemini returned no candidates.",
    );
  }

  const candidate =
    candidates[0];

  if (
    typeof candidate !==
      "object" ||
    candidate ===
      null
  ) {
    throw new Error(
      "Invalid Gemini candidate.",
    );
  }

  const content =
    (
      candidate as Record<
        string,
        unknown
      >
    )["content"];

  if (
    typeof content !==
      "object" ||
    content ===
      null
  ) {
    throw new Error(
      "Gemini returned no content.",
    );
  }

  const parts =
    (
      content as Record<
        string,
        unknown
      >
    )["parts"];

  if (
    !Array.isArray(parts)
  ) {
    throw new Error(
      "Gemini returned no content parts.",
    );
  }

  const text =
    parts
      .map(
        (
          part,
        ) => {
          if (
            typeof part !==
              "object" ||
            part ===
              null
          ) {
            return "";
          }

          return cleanMultilineString(
            (
              part as Record<
                string,
                unknown
              >
            )["text"],
            50000,
          );
        },
      )
      .filter(Boolean)
      .join("\n")
      .trim();

  if (!text) {
    throw new Error(
      "Gemini returned empty text.",
    );
  }

  let cleaned =
    text
      .replace(
        /^```json\s*/i,
        "",
      )
      .replace(
        /^```\s*/i,
        "",
      )
      .replace(
        /```\s*$/i,
        "",
      )
      .trim();

  const firstBrace =
    cleaned.indexOf("{");

  const lastBrace =
    cleaned.lastIndexOf("}");

  if (
    firstBrace >= 0 &&
    lastBrace >
      firstBrace
  ) {
    cleaned =
      cleaned.substring(
        firstBrace,
        lastBrace + 1,
      );
  }

  const parsed:
    unknown =
    JSON.parse(cleaned);

  if (
    typeof parsed !==
      "object" ||
    parsed ===
      null ||
    Array.isArray(
      parsed,
    )
  ) {
    throw new Error(
      "Gemini JSON root is invalid.",
    );
  }

  return parsed as Record<
    string,
    unknown
  >;
}

// ============================================================================
// Result sanitization
// ============================================================================

function sanitizeStatus(
  value: unknown,
): string {
  const normalized =
    cleanString(
      value,
      50,
    ).toLowerCase();

  const allowed =
    new Set<string>([
      "exact_medicine",
      "possible_medicine",
      "category_only",
      "unreadable",
    ]);

  if (
    allowed.has(
      normalized,
    )
  ) {
    return normalized;
  }

  return "unreadable";
}

function sanitizeConfidence(
  value: unknown,
): string {
  const normalized =
    cleanString(
      value,
      30,
    ).toLowerCase();

  const allowed =
    new Set<string>([
      "high",
      "medium",
      "low",
    ]);

  if (
    allowed.has(
      normalized,
    )
  ) {
    return normalized;
  }

  return "low";
}

function sanitizeRoute(
  value: unknown,
): string {
  const normalized =
    cleanString(
      value,
      50,
    ).toUpperCase();

  const allowed =
    new Set<string>([
      "ORAL",
      "RECTAL",
      "OPHTHALMIC",
      "OTIC",
      "TOPICAL",
      "IM",
      "IV",
      "INHALATION",
      "NASAL",
      "SUBLINGUAL",
      "TRANSDERMAL",
      "VAGINAL",
      "UNKNOWN",
    ]);

  if (
    allowed.has(
      normalized,
    )
  ) {
    return normalized;
  }

  return "UNKNOWN";
}

function sanitizeSuggestion(
  value: unknown,
): Record<string, unknown> |
  null {
  if (
    typeof value !==
      "object" ||
    value ===
      null ||
    Array.isArray(
      value,
    )
  ) {
    return null;
  }

  const raw =
    value as Record<
      string,
      unknown
    >;

  const identificationStatus =
    sanitizeStatus(
      raw[
        "identificationStatus"
      ],
    );

  const unreadable =
    identificationStatus ===
    "unreadable";

  const categoryOnly =
    identificationStatus ===
    "category_only";

  const name =
    unreadable ||
    categoryOnly
      ? ""
      : cleanString(
          raw["name"],
          300,
        );

  const genericName =
    unreadable ||
    categoryOnly
      ? ""
      : cleanString(
          raw[
            "genericName"
          ],
          300,
        );

  const result:
    Record<string, unknown> =
    {
      identificationStatus,

      exactWrittenText:
        cleanString(
          raw[
            "exactWrittenText"
          ],
          1200,
        ),

      writtenFragment:
        cleanString(
          raw[
            "writtenFragment"
          ],
          500,
        ),

      medicineCategory:
        cleanString(
          raw[
            "medicineCategory"
          ],
          300,
        ),

      name,

      genericName,

      strength:
        unreadable
          ? ""
          : cleanString(
              raw[
                "strength"
              ],
              200,
            ),

      form:
        unreadable
          ? ""
          : cleanString(
              raw["form"],
              150,
            ),

      dose:
        cleanString(
          raw["dose"],
          300,
        ),

      frequency:
        cleanString(
          raw[
            "frequency"
          ],
          300,
        ),

      duration:
        cleanString(
          raw[
            "duration"
          ],
          300,
        ),

      writtenInstructions:
        cleanString(
          raw[
            "writtenInstructions"
          ],
          1000,
        ),

      route:
        sanitizeRoute(
          raw["route"],
        ),

      routeConfidence:
        sanitizeConfidence(
          raw[
            "routeConfidence"
          ],
        ),

      routeEvidence:
        cleanString(
          raw[
            "routeEvidence"
          ],
          500,
        ),

      routeExplicitlyWritten:
        safeBoolean(
          raw[
            "routeExplicitlyWritten"
          ],
        ),

      confidence:
        sanitizeConfidence(
          raw[
            "confidence"
          ],
        ),

      reasons:
        cleanStringList(
          raw["reasons"],
          6,
        ),

      warnings:
        cleanStringList(
          raw["warnings"],
          6,
        ),

      requiresDoctorConfirmation:
        safeBoolean(
          raw[
            "requiresDoctorConfirmation"
          ],
        ) ||
        identificationStatus !==
          "exact_medicine",

      // ----------------------------------------------------------------------
      // Legacy compatibility fields
      // ----------------------------------------------------------------------
      //
      // They intentionally contain NO AI-generated clinical knowledge.
      // ----------------------------------------------------------------------

      specialtyMatch:
        "none",

      specialtyReason:
        "",

      catalogMatch:
        unreadable ||
        categoryOnly
          ? "not_applicable"
          : "not_found",

      possibleUse:
        "",

      problemMatch:
        "",

      patientExplanation:
        "",

      pharmacistChecks:
        [],

      redFlags:
        [],
    };

  return result;
}

function sanitizeResult(
  raw: Record<
    string,
    unknown
  >,
): Record<string, unknown> {
  const suggestions:
    Record<
      string,
      unknown
    >[] =
    [];

  const rawSuggestions =
    raw["suggestions"];

  if (
    Array.isArray(
      rawSuggestions,
    )
  ) {
    for (
      const rawSuggestion of
      rawSuggestions
    ) {
      const suggestion =
        sanitizeSuggestion(
          rawSuggestion,
        );

      if (!suggestion) {
        continue;
      }

      suggestions.push(
        suggestion,
      );

      if (
        suggestions.length >=
        20
      ) {
        break;
      }
    }
  }

  return {
    detectedDoctorName:
      cleanString(
        raw[
          "detectedDoctorName"
        ],
        300,
      ),

    detectedSpecialty:
      cleanString(
        raw[
          "detectedSpecialty"
        ],
        300,
      ),

    detectedPatientProblem:
      cleanString(
        raw[
          "detectedPatientProblem"
        ],
        500,
      ),

    rawInterpretation:
      cleanString(
        raw[
          "rawInterpretation"
        ],
        1500,
      ),

    suggestions,

    generalWarnings:
      cleanStringList(
        raw[
          "generalWarnings"
        ],
        8,
      ),
  };
}

function hasSuggestions(
  result: Record<
    string,
    unknown
  >,
): boolean {
  const suggestions =
    result["suggestions"];

  return (
    Array.isArray(
      suggestions,
    ) &&
    suggestions.length >
      0
  );
}

// ============================================================================
// Prescription analysis
// ============================================================================

async function analyzePrescription({
  imageBase64,
  imageMimeType,
  ocrText,
  doctorContext,
  responseLanguage,
}: {
  imageBase64:
    string;

  imageMimeType:
    string;

  ocrText:
    string;

  doctorContext:
    string;

  responseLanguage:
    "Arabic" | "English";
}): Promise<
  Record<string, unknown>
> {
  const apiKeys =
    geminiApiKeys();

  const models =
    geminiModels();

  if (
    apiKeys.length ===
    0
  ) {
    console.error(
      `[${FUNCTION_NAME}] no Gemini API key configured`,
    );

    throw new Error(
      "Gemini API key missing.",
    );
  }

  if (
    models.length ===
    0
  ) {
    console.error(
      `[${FUNCTION_NAME}] no Gemini model configured`,
    );

    throw new Error(
      "Gemini model missing.",
    );
  }

  let lastError:
    unknown =
    null;

  for (
    const model of models
  ) {
    for (
      const apiKey of apiKeys
    ) {
      try {
        const primaryRaw =
          await callGemini(
            {
              apiKey,

              model,

              imageBase64,

              imageMimeType,

              prompt:
                buildPrimaryPrompt(
                  {
                    responseLanguage,

                    doctorContext,

                    ocrText,
                  },
                ),

              maxOutputTokens:
                3800,
            },
          );

        const primary =
          sanitizeResult(
            primaryRaw,
          );

        if (
          hasSuggestions(
            primary,
          )
        ) {
          return primary;
        }

        // --------------------------------------------------------------------
        // Recovery attempt
        // --------------------------------------------------------------------

        const recoveryRaw =
          await callGemini(
            {
              apiKey,

              model,

              imageBase64,

              imageMimeType,

              prompt:
                buildRecoveryPrompt(
                  {
                    responseLanguage,

                    ocrText,
                  },
                ),

              maxOutputTokens:
                2800,
            },
          );

        const recovery =
          sanitizeResult(
            recoveryRaw,
          );

        if (
          hasSuggestions(
            recovery,
          )
        ) {
          return recovery;
        }

        return {
          ...recovery,

          suggestions:
            [],

          generalWarnings: [
            responseLanguage ===
            "Arabic"
              ? "لم يتم استخراج أسطر دوائية قابلة للاستخدام. حاول استخدام صورة أوضح ومقرّبة من منطقة الأدوية."
              : "No usable medication lines were extracted. Try a clearer image cropped closer to the medicine area.",
          ],
        };
      } catch (error) {
        lastError =
          error;

        console.error(
          `[${FUNCTION_NAME}] Gemini attempt failed for model ${model}`,
        );

        if (
          error instanceof
            GeminiRequestError &&
          !error.retryable
        ) {
          throw error;
        }
      }
    }
  }

  console.error(
    `[${FUNCTION_NAME}] all Gemini attempts failed`,
    lastError,
  );

  throw new Error(
    "All Gemini attempts failed.",
  );
}

// ============================================================================
// Main HTTP handler
// ============================================================================

Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    // ------------------------------------------------------------------------
    // Browser preflight
    // ------------------------------------------------------------------------

    if (
      request.method ===
      "OPTIONS"
    ) {
      return new Response(
        "ok",
        {
          headers:
            corsHeaders,
        },
      );
    }

    // ------------------------------------------------------------------------
    // POST only
    // ------------------------------------------------------------------------

    if (
      request.method !==
      "POST"
    ) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "method_not_allowed",

          message:
            "Method not allowed.",
        },
        405,
      );
    }

    // ------------------------------------------------------------------------
    // Authentication
    // ------------------------------------------------------------------------

    let userId:
      string;

    try {
      userId =
        await authenticatedUserId(
          request,
        );
    } catch (
      error
    ) {
      console.warn(
        `[${FUNCTION_NAME}] unauthorized request`,
      );

      return jsonResponse(
        {
          ok:
            false,

          code:
            "unauthorized",

          message:
            "An authenticated application session is required.",
        },
        401,
      );
    }

    // ------------------------------------------------------------------------
    // Read request JSON
    // ------------------------------------------------------------------------

    let body:
      Record<
        string,
        unknown
      >;

    try {
      const parsed:
        unknown =
        await request.json();

      if (
        typeof parsed !==
          "object" ||
        parsed ===
          null ||
        Array.isArray(
          parsed,
        )
      ) {
        throw new Error(
          "Invalid request body.",
        );
      }

      body =
        parsed as Record<
          string,
          unknown
        >;
    } catch {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "invalid_request",

          message:
            "Invalid request.",
        },
        400,
      );
    }

    // ------------------------------------------------------------------------
    // Image validation
    // ------------------------------------------------------------------------

    const imageBase64 =
      cleanMultilineString(
        body[
          "imageBase64"
        ],
        MAX_BASE64_CHARACTERS,
      );

    const imageMimeType =
      cleanString(
        body[
          "imageMimeType"
        ],
        100,
      ).toLowerCase();

    if (!imageBase64) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "invalid_image",

          message:
            "The prescription image is empty.",
        },
        400,
      );
    }

    if (
      !supportedMimeType(
        imageMimeType,
      )
    ) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "unsupported_image",

          message:
            "This prescription image format is not supported.",
        },
        415,
      );
    }

    const approximateBytes =
      approximateBase64Bytes(
        imageBase64,
      );

    if (
      approximateBytes <=
      0
    ) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "invalid_image",

          message:
            "The prescription image could not be processed.",
        },
        400,
      );
    }

    if (
      approximateBytes >
      MAX_IMAGE_BYTES
    ) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "image_too_large",

          message:
            "The prescription image is too large.",
        },
        413,
      );
    }

    // ------------------------------------------------------------------------
    // Rate limit
    // ------------------------------------------------------------------------

    let quota:
      QuotaResult;

    try {
      quota =
        await consumeQuota(
          userId,
        );
    } catch (
      error
    ) {
      console.error(
        `[${FUNCTION_NAME}] rate limiter unavailable`,
        error,
      );

      return jsonResponse(
        {
          ok:
            false,

          code:
            "service_unavailable",

          message:
            "Prescription analysis is temporarily unavailable.",
        },
        503,
      );
    }

    if (
      !quota.allowed
    ) {
      return jsonResponse(
        {
          ok:
            false,

          code:
            "rate_limited",

          message:
            "Too many prescription analysis requests. Please try again later.",

          resetAt:
            quota.resetAt,
        },
        429,
      );
    }

    // ------------------------------------------------------------------------
    // Supporting information
    // ------------------------------------------------------------------------

    const ocrText =
      cleanMultilineString(
        body["ocrText"],
        MAX_OCR_CHARACTERS,
      );

    const doctorContext =
      cleanString(
        body[
          "doctorContext"
        ],
        MAX_DOCTOR_CONTEXT_CHARACTERS,
      );

    const responseLanguage =
      normalizeResponseLanguage(
        body[
          "responseLanguage"
        ],
      );

    // ------------------------------------------------------------------------
    // Analyze
    // ------------------------------------------------------------------------

    try {
      const result =
        await analyzePrescription(
          {
            imageBase64,

            imageMimeType,

            ocrText,

            doctorContext,

            responseLanguage,
          },
        );

      return jsonResponse(
        {
          ok:
            true,

          result,
        },
        200,
      );
    } catch (
      error
    ) {
      console.error(
        `[${FUNCTION_NAME}] prescription analysis failed`,
        error,
      );

      /*
       * Never send provider error details to Flutter.
       */
      return jsonResponse(
        {
          ok:
            false,

          code:
            "analysis_unavailable",

          message:
            "Prescription analysis is temporarily unavailable.",
        },
        503,
      );
    }
  },
);