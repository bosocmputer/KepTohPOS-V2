import 'package:flutter_bloc/flutter_bloc.dart';

/// Processes bloc events strictly in order, one at a time.
///
/// Handlers that await a repository command would otherwise overlap: the next
/// event would read the state from before the previous command finished.
EventTransformer<E> sequentialEvents<E>() =>
    (events, mapper) => events.asyncExpand(mapper);
