import 'package:flutter/material.dart';
import '../services/lrclib_service.dart';
import '../utils/constants.dart';

/// Returned when the user picks an online result.
/// Returned as the string sentinel 'file' when they want the file picker.
class LrcSearchDialog extends StatefulWidget {
  final String songTitle;
  const LrcSearchDialog({super.key, required this.songTitle});

  @override
  State<LrcSearchDialog> createState() => _LrcSearchDialogState();
}

class _LrcSearchDialogState extends State<LrcSearchDialog> {
  late final TextEditingController _ctrl;
  List<LrclibResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.songTitle);
    if (widget.songTitle.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _searched = false; });
    try {
      final results = await LrclibService.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
        if (results.isEmpty) _error = 'No synced lyrics found for "$q"';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
        _error = 'Could not reach lrclib.net — check your internet connection';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const _HDivider(),
            Flexible(child: _buildBody()),
            const _HDivider(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.lyrics_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Find Synced Lyrics',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.uiHint,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Artist · Song title',
                hintStyle: const TextStyle(
                  fontFamily: AppTextStyles.ui,
                  fontSize: 13,
                  color: AppColors.uiHint,
                ),
                filled: true,
                fillColor: AppColors.surfaceSelected,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          _SearchButton(onTap: _search, loading: _loading),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 12,
              color: AppColors.uiHint,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    if (!_searched) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.hairline,
      ),
      itemBuilder: (_, i) => _ResultTile(
        result: _results[i],
        onTap: () => Navigator.of(context).pop(_results[i]),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 12, color: AppColors.uiHint),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Powered by lrclib.net — free, open lyrics database',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 10,
                color: AppColors.uiHint,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop('file'),
            child: const Text(
              'Load from file',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 11,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final LrclibResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.trackName,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (result.artistName.isNotEmpty) result.artistName,
                      if (result.albumName.isNotEmpty) result.albumName,
                    ].join(' · '),
                    style: const TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 11,
                      color: AppColors.uiHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              result.durationLabel,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 11,
                color: AppColors.uiHint,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.uiHint),
          ],
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _SearchButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Search',
          style: TextStyle(
            fontFamily: AppTextStyles.ui,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _HDivider extends StatelessWidget {
  const _HDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.hairline);
}
