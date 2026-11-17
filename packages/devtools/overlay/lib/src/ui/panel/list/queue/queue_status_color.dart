import 'package:flutter/painting.dart';
import 'package:qora/qora.dart';
import 'package:qora_devtools_overlay/src/ui/theme/devtools_colors.dart';

/// One color per queue status, shared by the row dot and the badge.
Color queueStatusColor(QueuedMutationStatus status) => switch (status) {
      QueuedMutationStatus.queued => DevtoolsColors.statusIdle,
      QueuedMutationStatus.sending => DevtoolsColors.statusFetching,
      QueuedMutationStatus.held => DevtoolsColors.statusStale,
      QueuedMutationStatus.blocked ||
      QueuedMutationStatus.failed =>
        DevtoolsColors.statusError,
    };
