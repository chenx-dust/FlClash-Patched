part of 'input.dart';

class ListInputPage extends ConsumerStatefulWidget {
  final String title;
  final List<String> items;
  final Widget Function(String item) titleBuilder;
  final Widget Function(String item)? subtitleBuilder;
  final Widget Function(String item)? leadingBuilder;
  final String? valueLabel;
  final int? itemMaxLength;

  const ListInputPage({
    super.key,
    required this.title,
    required this.items,
    required this.titleBuilder,
    this.leadingBuilder,
    this.valueLabel,
    this.subtitleBuilder,
    this.itemMaxLength,
  });

  @override
  ConsumerState createState() => _ListInputPageState();
}

mixin _DragSelectionMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final Map<String, GlobalKey> _dragSelectionKeys = {};
  Set<String> _initialDragSelectedIds = {};
  bool _dragSelectionValue = false;
  int? _dragSelectionStartIndex;
  int? _lastDragSelectionIndex;

  List<String> get dragSelectionIds;
  Set<dynamic> get dragSelectedIds;
  void setDragSelected(String id, bool selected);

  GlobalKey dragSelectionKey(String id) {
    return _dragSelectionKeys.putIfAbsent(id, GlobalKey.new);
  }

  void startDragSelection(String id, LongPressStartDetails details) {
    final index = dragSelectionIds.indexOf(id);
    if (index == -1) return;
    _initialDragSelectedIds = dragSelectedIds.whereType<String>().toSet();
    _dragSelectionValue = !_initialDragSelectedIds.contains(id);
    _dragSelectionStartIndex = index;
    _lastDragSelectionIndex = index;
    setDragSelected(id, _dragSelectionValue);
    _updateDragSelectionAt(details.globalPosition);
  }

  void updateDragSelection(LongPressMoveUpdateDetails details) {
    _updateDragSelectionAt(details.globalPosition);
  }

  void _updateDragSelectionAt(Offset globalPosition) {
    final index = _indexAt(globalPosition);
    final startIndex = _dragSelectionStartIndex;
    final lastIndex = _lastDragSelectionIndex;
    if (index == null || startIndex == null || lastIndex == null) return;
    if (index == lastIndex) return;
    final previousStart = startIndex < lastIndex ? startIndex : lastIndex;
    final previousEnd = startIndex > lastIndex ? startIndex : lastIndex;
    final currentStart = startIndex < index ? startIndex : index;
    final currentEnd = startIndex > index ? startIndex : index;
    final affectedStart = previousStart < currentStart
        ? previousStart
        : currentStart;
    final affectedEnd = previousEnd > currentEnd ? previousEnd : currentEnd;
    for (var current = affectedStart; current <= affectedEnd; current++) {
      final id = dragSelectionIds[current];
      final isInCurrentRange = current >= currentStart && current <= currentEnd;
      setDragSelected(
        id,
        isInCurrentRange
            ? _dragSelectionValue
            : _initialDragSelectedIds.contains(id),
      );
    }
    _lastDragSelectionIndex = index;
  }

  void endDragSelection([LongPressEndDetails? details]) {
    _initialDragSelectedIds = {};
    _dragSelectionStartIndex = null;
    _lastDragSelectionIndex = null;
  }

  int? _indexAt(Offset globalPosition) {
    final ids = dragSelectionIds;
    for (var index = 0; index < ids.length; index++) {
      final context = _dragSelectionKeys[ids[index]]?.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final position = renderObject.globalToLocal(globalPosition);
      if ((Offset.zero & renderObject.size).contains(position)) return index;
    }
    return null;
  }
}

class _ListInputPageState extends ConsumerState<ListInputPage>
    with _DragSelectionMixin<ListInputPage> {
  List<String> _items = [];
  late List<String> _originItems;
  final _key = uniqueId;

  @override
  List<String> get dragSelectionIds => _items;

  @override
  Set<dynamic> get dragSelectedIds => ref.read(itemsProvider(_key));

  @override
  void setDragSelected(String id, bool selected) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      if (state.contains(id) == selected) return state;
      final nextState = Set<String>.from(state);
      selected ? nextState.add(id) : nextState.remove(id);
      return nextState;
    });
  }

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    _originItems = List<String>.from(_items);
  }

  void _handleReorder(int oldIndex, newIndex) {
    _items = _items.copyAndReorder(oldIndex, newIndex);
    setState(() {});
  }

  void _handleSelected(String value) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      final newState = Set<String>.from(state)..addOrRemove(value);
      return newState;
    });
  }

  void _handleSelectAll() {
    final ids = _items.toSet();
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  static final _separator = RegExp(r'[,，]');

  List<String> _splitValues(String? value) {
    return (value ?? '')
        .split(_separator)
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _handleAddOrEdit([String? item]) async {
    final appLocalizations = context.appLocalizations;
    final label = widget.valueLabel ?? appLocalizations.value;
    final isEdit = item != null;

    String? editValidator(String? value) {
      final exists = _items.contains(value) && value != item;
      return exists ? appLocalizations.existsTip(label) : null;
    }

    String? addValidator(String? value) {
      final values = _splitValues(value);
      if (values.isEmpty) {
        return appLocalizations.emptyTip(label);
      }
      final maxLength = widget.itemMaxLength;
      if (maxLength != null && values.any((v) => v.length > maxLength)) {
        return appLocalizations.maxLengthTip(label, maxLength);
      }
      if (values.any(_items.contains)) {
        return appLocalizations.existsTip(label);
      }
      return null;
    }

    final value = await dialogs.showCommonDialog<String>(
      child: AddDialog(
        valueField: Field(
          label: label,
          value: item ?? '',
          validator: isEdit ? editValidator : addValidator,
        ),
        valueMaxLength: isEdit ? widget.itemMaxLength : null,
        valueHelperText: isEdit ? null : appLocalizations.multipleValuesTip,
        title: isEdit ? appLocalizations.edit : appLocalizations.add,
      ),
    );

    if (!mounted) return;
    if (value == null) return;
    final nextItems = List<String>.from(_items);
    if (isEdit) {
      nextItems[_items.indexOf(item)] = value;
    } else {
      nextItems.addAll(_splitValues(value));
    }
    _items = nextItems;
    setState(() {});
  }

  void _handleDelete() {
    final selectedItems = ref.read(itemsProvider(_key));
    final newItems = _items
        .where((item) => !selectedItems.contains(item))
        .toList();
    _items = newItems;
    ref.read(itemsProvider(_key).notifier).value = {};
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await dialogs.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (!mounted || res != true) {
      return;
    }
    _items = _originItems;
    setState(() {});
  }

  Widget _buildItem({
    required String value,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
    bool trackDragSelection = true,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(value),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: KeyedSubtree(
          key: trackDragSelection ? dragSelectionKey(value) : null,
          child: SelectedDecorationListItem(
            title: widget.titleBuilder(value),
            isSelected: isSelected,
            isEditing: isEditing,
            onSelected: () {
              _handleSelected(value);
            },
            onPressed: () {
              _handleAddOrEdit(value);
            },
            onSelectionDragStart: trackDragSelection
                ? (details) => startDragSelection(value, details)
                : null,
            onSelectionDragUpdate: trackDragSelection
                ? updateDragSelection
                : null,
            onSelectionDragEnd: trackDragSelection ? endDragSelection : null,
            onSelectionDragCancel: trackDragSelection ? endDragSelection : null,
            leading: widget.leadingBuilder != null
                ? widget.leadingBuilder!(value)
                : null,
            subtitle: widget.subtitleBuilder != null
                ? widget.subtitleBuilder!(value)
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final selectedItems = ref.watch(itemsProvider(_key));
    return CommonPopScope(
      onPop: (_) {
        if (selectedItems.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
          return false;
        }
        Navigator.of(context).pop(_items);
        return false;
      },
      child: CommonScaffold(
        title: widget.title,
        actions: [
          if (selectedItems.isNotEmpty) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.delete,
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (!stringListEquality.equals(_items, _originItems)) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.reset,
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedItems.isNotEmpty
                ? FilledButton(
                    onPressed: _handleSelectAll,
                    child: Text(appLocalizations.selectAll),
                  )
                : FilledButton.tonal(
                    onPressed: () {
                      _handleAddOrEdit();
                    },
                    child: Text(appLocalizations.add),
                  ),
          ),
          const SizedBox(width: 8),
        ],
        body: _items.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 16 + 64,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final value = _items[index];
                  return _buildItem(
                    value: value,
                    index: index,
                    length: _items.length,
                    isSelected: selectedItems.contains(value),
                    isEditing: selectedItems.isNotEmpty,
                  );
                },
                proxyDecorator: (child, index, animation) {
                  final value = _items[index];
                  return commonProxyDecorator(
                    _buildItem(
                      value: value,
                      index: index,
                      length: _items.length,
                      isSelected: selectedItems.contains(value),
                      isEditing: selectedItems.isNotEmpty,
                      trackDragSelection: false,
                    ),
                    index,
                    animation,
                  );
                },
                onReorderItem: _handleReorder,
              ),
      ),
    );
  }
}

class MapInputPage extends ConsumerStatefulWidget {
  final String title;
  final Map<String, String> map;
  final Widget Function(MapEntry<String, String> item) titleBuilder;
  final Widget Function(MapEntry<String, String> item)? subtitleBuilder;
  final Widget Function(MapEntry<String, String> item)? leadingBuilder;
  final String? keyLabel;
  final String? valueLabel;
  final int? keyMaxLength;
  final int? valueMaxLength;

  const MapInputPage({
    super.key,
    required this.title,
    required this.map,
    required this.titleBuilder,
    this.leadingBuilder,
    this.keyLabel,
    this.valueLabel,
    this.subtitleBuilder,
    this.keyMaxLength,
    this.valueMaxLength,
  });

  @override
  ConsumerState<MapInputPage> createState() => _MapInputPageState();
}

class _MapInputPageState extends ConsumerState<MapInputPage>
    with _DragSelectionMixin<MapInputPage> {
  List<MapEntry<String, String>> _items = [];
  late final List<MapEntry<String, String>> _originItems;
  final _key = uniqueId;

  @override
  List<String> get dragSelectionIds => _items.map((item) => item.key).toList();

  @override
  Set<dynamic> get dragSelectedIds => ref.read(itemsProvider(_key));

  @override
  void setDragSelected(String id, bool selected) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      if (state.contains(id) == selected) return state;
      final nextState = Set<String>.from(state);
      selected ? nextState.add(id) : nextState.remove(id);
      return nextState;
    });
  }

  @override
  void initState() {
    super.initState();
    _items = List<MapEntry<String, String>>.from(widget.map.entries);
    _originItems = List<MapEntry<String, String>>.from(_items);
  }

  void _handleReorder(int oldIndex, newIndex) {
    _items = _items.copyAndReorder(oldIndex, newIndex);
    setState(() {});
  }

  void _handleSelected(MapEntry<String, String> value) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      final newState = Set<String>.from(state)..addOrRemove(value.key);
      return newState;
    });
  }

  void _handleSelectAll() {
    final ids = _items.map((item) => item.key).toSet();
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleAddOrEdit([MapEntry<String, String>? item]) async {
    final appLocalizations = context.appLocalizations;
    String? uniqueValidator(String? value) {
      final index = _items.indexWhere((entry) {
        return entry.key == value;
      });
      final current = item?.key == value;
      if (index != -1 && !current) {
        return appLocalizations.existsTip(appLocalizations.key);
      }
      return null;
    }

    final keyField = Field(
      label: widget.keyLabel ?? appLocalizations.key,
      value: item == null ? '' : item.key,
      validator: uniqueValidator,
    );

    final valueField = Field(
      label: widget.valueLabel ?? appLocalizations.value,
      value: item == null ? '' : item.value,
    );

    final value = await dialogs.showCommonDialog<MapEntry<String, String>>(
      child: AddDialog(
        keyField: keyField,
        valueField: valueField,
        keyMaxLength: widget.keyMaxLength,
        valueMaxLength: widget.valueMaxLength,
        title: item != null ? appLocalizations.edit : appLocalizations.add,
      ),
    );
    if (!mounted) return;
    if (value == null) return;
    final index = _items.indexWhere((entry) {
      return entry.key == item?.key;
    });

    final nextItems = List<MapEntry<String, String>>.from(_items);
    if (item != null) {
      nextItems[index] = value;
    } else {
      nextItems.add(value);
    }
    _items = nextItems;
    setState(() {});
  }

  void _handleDelete() {
    final selectedItems = ref.read(itemsProvider(_key));
    final newItems = _items
        .where((item) => !selectedItems.contains(item.key))
        .toList();
    _items = newItems;
    ref.read(itemsProvider(_key).notifier).value = {};
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await dialogs.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (!mounted || res != true) {
      return;
    }
    _items = _originItems;
    setState(() {});
  }

  Widget _buildItem({
    required MapEntry<String, String> value,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
    bool trackDragSelection = true,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(value.key),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: KeyedSubtree(
          key: trackDragSelection ? dragSelectionKey(value.key) : null,
          child: SelectedDecorationListItem(
            title: widget.titleBuilder(value),
            leading: widget.leadingBuilder != null
                ? widget.leadingBuilder!(value)
                : null,
            subtitle: widget.subtitleBuilder != null
                ? widget.subtitleBuilder!(value)
                : null,
            isSelected: isSelected,
            isEditing: isEditing,
            onSelected: () {
              _handleSelected(value);
            },
            onPressed: () {
              _handleAddOrEdit(value);
            },
            onSelectionDragStart: trackDragSelection
                ? (details) => startDragSelection(value.key, details)
                : null,
            onSelectionDragUpdate: trackDragSelection
                ? updateDragSelection
                : null,
            onSelectionDragEnd: trackDragSelection ? endDragSelection : null,
            onSelectionDragCancel: trackDragSelection ? endDragSelection : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final selectedItems = ref.watch(itemsProvider(_key));
    return CommonPopScope(
      onPop: (_) {
        if (selectedItems.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
          return false;
        }
        Navigator.of(context).pop(Map<String, String>.fromEntries(_items));
        return false;
      },
      child: CommonScaffold(
        title: widget.title,
        actions: [
          if (selectedItems.isNotEmpty) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.delete,
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (!stringAndStringMapEntryListEquality.equals(
            _items,
            _originItems,
          )) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                tooltip: context.appLocalizations.reset,
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedItems.isNotEmpty
                ? FilledButton(
                    onPressed: _handleSelectAll,
                    child: Text(appLocalizations.selectAll),
                  )
                : FilledButton.tonal(
                    onPressed: () {
                      _handleAddOrEdit();
                    },
                    child: Text(appLocalizations.add),
                  ),
          ),
          const SizedBox(width: 8),
        ],
        body: _items.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 16 + 64,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final value = _items[index];
                  return _buildItem(
                    value: value,
                    index: index,
                    length: _items.length,
                    isSelected: selectedItems.contains(value.key),
                    isEditing: selectedItems.isNotEmpty,
                  );
                },
                proxyDecorator: (child, index, animation) {
                  final value = _items[index];
                  return commonProxyDecorator(
                    _buildItem(
                      value: value,
                      index: index,
                      length: _items.length,
                      isSelected: selectedItems.contains(value.key),
                      isEditing: selectedItems.isNotEmpty,
                      trackDragSelection: false,
                    ),
                    index,
                    animation,
                  );
                },
                onReorderItem: _handleReorder,
              ),
      ),
    );
  }
}
