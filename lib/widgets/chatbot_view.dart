import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../services/chatbot_service.dart';
import '../theme/pharmalens_theme.dart';

class ChatbotView extends StatefulWidget {
  const ChatbotView({super.key, this.asSidePanel = false});

  /// Full-height docked panel (wide windows) instead of a bottom sheet.
  final bool asSidePanel;

  static Future<void> showAsBottomSheet(BuildContext context) {
    final isDark = PharmaLensTheme.isDark(context);
    final barrier = Colors.black.withValues(alpha: isDark ? 0.70 : 0.45);

    // On wide windows the assistant docks to the side instead of covering
    // the page from the bottom.
    if (MediaQuery.sizeOf(context).width >= 900) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: barrier.withValues(alpha: isDark ? 0.45 : 0.25),
        transitionDuration: const Duration(milliseconds: 220),
        // Unlike bottom sheets, general dialogs add no Material ancestor, which
        // TextField, chips and ink effects require.
        pageBuilder: (dialogContext, animation, secondaryAnimation) => const SafeArea(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 440,
                child: Material(
                  type: MaterialType.transparency,
                  child: ChatbotView(asSidePanel: true),
                ),
              ),
            ),
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(isRtl ? -0.15 : 0.15, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: barrier,
      builder: (_) => const ChatbotView(),
    );
  }

  @override
  State<ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<ChatbotView> {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _attachedImageBytes;
  String? _attachedImageMimeType;
  bool _isSending = false;

  bool get _isArabic {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  }

  String _text({required String en, required String ar}) {
    return _isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chatbotService.conversationHistory.isEmpty) {
        _addWelcomeMessage();
      }
    });
  }

  void _addWelcomeMessage() {
    final greeting = _text(
      en: 'Hello! I am PharmaLens AI Assistant 🤖\n\nI can help you with:\n'
          '• 📷 **Prescription Vision**: Send a photo to see prices, usage instructions written by doctor, and cheaper alternatives.\n'
          '• 💲 **Medicine Info & Prices**: Search official MOPH Lebanon prices.\n'
          '• 📍 **Nearby Pharmacies**: Find active pharmacies in your area.\n'
          '• 💊 **Generic Alternatives**: Discover exact composition lower-cost brands.',
      ar: 'أهلاً بك! أنا مساعد PharmaLens الذكي 🤖\n\nيمكنني مساعدتك في:\n'
          '• 📷 **تحليل الوصفة**: أرسل صورة لمعرفة الأسعار، تعليمات الطبيب، والبدائل المتاحة.\n'
          '• 💲 **معلومات وأسعار الأدوية**: استعلام تسعيرة وزارة الصحة اللبنانية (MOPH).\n'
          '• 📍 **صيدليات قريبة**: البحث عن الصيدليات المتاحة في منطقتك.\n'
          '• 💊 **البدائل المتطابقة**: اكتشاف بدائل بنفس التركيبة وسعر أوفر.',
    );

    _chatbotService.addWelcomeMessage(greeting);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (bytes.isEmpty) return;

      setState(() {
        _attachedImageBytes = bytes;
        _attachedImageMimeType = picked.mimeType ?? 'image/jpeg';
      });
    } catch (error) {
      _showSnackBar(
        _text(
          en: 'Could not attach image. Please try again.',
          ar: 'تعذر إرفاق الصورة. يرجى إعادة المحاولة.',
        ),
      );
    }
  }

  void _removeAttachedImage() {
    setState(() {
      _attachedImageBytes = null;
      _attachedImageMimeType = null;
    });
  }

  Future<void> _handleSend({String? overrideText}) async {
    final text = (overrideText ?? _textController.text).trim();

    if (text.isEmpty && _attachedImageBytes == null) {
      return;
    }

    if (_isSending) return;

    final imageBytesToSend = _attachedImageBytes;
    final imageMimeToSend = _attachedImageMimeType;

    setState(() {
      _isSending = true;
      _attachedImageBytes = null;
      _attachedImageMimeType = null;
      if (overrideText == null) {
        _textController.clear();
      }
    });

    _scrollToBottom();

    final promptText = text.isEmpty
        ? _text(
            en: 'Please analyze this prescription image for me.',
            ar: 'يرجى قراءة هذه الوصفة وتحليل الأدوية والأسعار والبدائل فيها.',
          )
        : text;

    await _chatbotService.sendMessage(
      userText: promptText,
      imageBytes: imageBytesToSend,
      imageMimeType: imageMimeToSend,
      responseLanguage: _isArabic ? 'ar' : 'en',
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _clearChatHistory() {
    setState(() {
      _chatbotService.clearHistory();
      _addWelcomeMessage();
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PharmaLensTheme.paletteOf(context);
    final isDark = PharmaLensTheme.isDark(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      height: widget.asSidePanel ? double.infinity : mediaQuery.size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      clipBehavior: widget.asSidePanel ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: widget.asSidePanel
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!widget.asSidePanel) _buildDragHandle(palette),
          _buildHeader(palette, isDark),
          const Divider(height: 1),
          _buildQuickSuggestions(palette),
          Expanded(
            child: _buildMessagesList(palette, isDark),
          ),
          if (_attachedImageBytes != null) _buildImagePreviewBar(palette),
          _buildComposerBar(palette, isDark),
        ],
      ),
    );
  }

  Widget _buildDragHandle(PharmaLensPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 42,
        height: 4.5,
        decoration: BoxDecoration(
          color: palette.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildHeader(PharmaLensPalette palette, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 14, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PharmaLensColors.cyan, PharmaLensColors.teal],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: PharmaLensColors.teal.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _text(en: 'PharmaLens AI', ar: 'مساعد PharmaLens'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: PharmaLensColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MOPH API',
                        style: TextStyle(
                          color: PharmaLensColors.teal,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _text(
                          en: 'Prescription Vision & Price Assistant',
                          ar: 'مساعد تحليل الوصفات والأسعار',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: palette.textMuted),
            tooltip: _text(en: 'Clear chat', ar: 'مسح المحادثة'),
            onPressed: _clearChatHistory,
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: palette.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(PharmaLensPalette palette) {
    final suggestions = <Map<String, String>>[
      {
        'label': _text(en: '📷 Analyze Prescription', ar: '📷 تحليل وصفة'),
        'prompt': _text(
          en: 'How do I upload a prescription image to find prices and alternatives?',
          ar: 'كيف أرفع صورة وصفة طبية لمرفة الأسعار والبدائل؟',
        ),
      },
      {
        'label': _text(en: '💲 Panadol 500mg Price', ar: '💲 سعر بنادول 500 ملغ'),
        'prompt': _text(
          en: 'What is the official MOPH price of Panadol 500mg and what cheaper alternatives exist?',
          ar: 'ما سعر بنادول 500ملغ الرسمي في لبنان وما هي البدائل الأوفر؟',
        ),
      },
      {
        'label': _text(en: '📍 Nearby Pharmacies', ar: '📍 صيدليات قريبة'),
        'prompt': _text(
          en: 'Find nearby open pharmacies near me with contact details.',
          ar: 'جد لي صيدليات قريبة مفتوحة مع أرقام التواصل.',
        ),
      },
      {
        'label': _text(en: '💊 Augmentin 1g Alternative', ar: '💊 بديل أوجمنتين 1غ'),
        'prompt': _text(
          en: 'What are the cheaper generic alternatives for Augmentin 1g?',
          ar: 'ما هي بدائل أوجمنتين 1غ الأقل سعراً ونفس التركيبة؟',
        ),
      },
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = suggestions[index];
          return ActionChip(
            label: Text(
              item['label']!,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: palette.tealSurface,
            side: BorderSide(
              color: PharmaLensColors.teal.withValues(alpha: 0.25),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _handleSend(overrideText: item['prompt']),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList(PharmaLensPalette palette, bool isDark) {
    final history = _chatbotService.conversationHistory;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: history.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == history.length && _isSending) {
          return _buildTypingIndicator(palette);
        }

        final msg = history[index];
        return _buildMessageBubble(msg, palette, isDark);
      },
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    PharmaLensPalette palette,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: PharmaLensColors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? PharmaLensColors.teal
                    : (msg.isError ? palette.dangerSurface : palette.surfaceSoft),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? PharmaLensColors.danger.withValues(alpha: 0.3)
                            : palette.border,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        msg.imageBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SelectableText(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser
                          ? Colors.white
                          : (msg.isError ? PharmaLensColors.danger : palette.textPrimary),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (msg.isBot && msg.sources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: msg.sources.map((src) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: PharmaLensColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '📍 $src',
                            style: const TextStyle(
                              color: PharmaLensColors.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: palette.textPrimary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(PharmaLensPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: PharmaLensColors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: palette.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  _text(
                    en: 'PharmaLens AI is analyzing data...',
                    ar: 'مساعد PharmaLens يحلل البيانات...',
                  ),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewBar(PharmaLensPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: palette.tealSurface,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _attachedImageBytes!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text(
                en: 'Prescription photo attached',
                ar: 'صورة الوصفة مرفقة',
              ),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: PharmaLensColors.danger),
            onPressed: _removeAttachedImage,
          ),
        ],
      ),
    );
  }

  Widget _buildComposerBar(PharmaLensPalette palette, bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt_rounded, color: PharmaLensColors.teal),
              tooltip: _text(en: 'Take Photo', ar: 'التقاط صورة'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_rounded, color: PharmaLensColors.teal),
              tooltip: _text(en: 'Choose Photo', ar: 'اختيار صورة'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: _text(
                    en: 'Ask medicine, price, or prescription...',
                    ar: 'اسأل عن دواء، سعر، أو وصفة...',
                  ),
                  hintStyle: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13.5,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: palette.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: PharmaLensColors.teal, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: PharmaLensColors.teal,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: _isSending ? null : () => _handleSend(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingChatbotButton extends StatelessWidget {
  const FloatingChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: PharmaLensColors.teal.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'floating_chatbot_btn',
        onPressed: () => ChatbotView.showAsBottomSheet(context),
        backgroundColor: PharmaLensColors.teal,
        elevation: 4,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
        label: Text(
          isArabic ? 'المساعد الذكي' : 'AI Assistant',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

