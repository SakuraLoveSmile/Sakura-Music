import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.empty,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final Widget? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('加载失败：$error', textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
      data: (value) =>
          _isEmpty(value) ? (empty ?? const _EmptyState()) : data(value),
    );
  }

  bool _isEmpty(T value) {
    if (value is Iterable) {
      return value.isEmpty;
    }
    return false;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('暂时没有内容'));
  }
}
