import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import 'update_models.dart';

class UpdateChannelController extends AsyncNotifier<UpdateChannel> {
  @override
  Future<UpdateChannel> build() async {
    final row = await ref.watch(settingsRepositoryProvider).read();
    return row?.updateChannel == UpdateChannel.prerelease.name
        ? UpdateChannel.prerelease
        : UpdateChannel.stable;
  }

  Future<void> setChannel(UpdateChannel channel) async {
    final previous = await future;
    if (channel == previous) return;
    // Riverpod has no public constructor for loading with retained data.
    // Keep the saved choice visible while making .future wait for the commit.
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<UpdateChannel>().copyWithPrevious(
      AsyncData(previous),
      isRefresh: false,
    );
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateUpdateChannel(updateChannel: channel.name);
      if (ref.mounted) state = AsyncData(channel);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final updateChannelProvider =
    AsyncNotifierProvider<UpdateChannelController, UpdateChannel>(
      UpdateChannelController.new,
    );
