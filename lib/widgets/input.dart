import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/null_status.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'effect.dart';
import 'list.dart';
import 'theme.dart';

class OptionsDialog<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T value;
  final String Function(T value) textBuilder;

  const OptionsDialog({
    super.key,
    required this.title,
    required this.options,
    required this.textBuilder,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: title,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: RadioGroup(
        onChanged: (value) {
          Navigator.of(context).pop(value);
        },
        groupValue: value,
        child: Wrap(
          children: [
            for (final option in options)
              Builder(
                builder: (context) {
                  if (value == option) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Scrollable.ensureVisible(context);
                    });
                  }
                  return ListItem.radio(
                    value: option,
                    onTap: () {
                      Navigator.of(context).pop(option);
                    },
                    title: Text(textBuilder(option)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class CommonCheckBox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool isCircle;

  const CommonCheckBox({
    required this.value,
    required this.onChanged,
    this.isCircle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      shape: isCircle ? const CircleBorder() : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class InputDialog extends StatefulWidget {
  final String title;
  final String value;
  final String? suffixText;
  final String? labelText;
  final String? resetValue;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final bool? obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  const InputDialog({
    super.key,
    required this.title,
    required this.value,
    this.suffixText,
    this.resetValue,
    this.hintText,
    this.validator,
    this.obscureText,
    this.labelText,
    this.maxLength,
    this.inputFormatters,
    this.keyboardType,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _textController;

  String get value => widget.value;

  String get title => widget.title;

  String? get suffixText => widget.suffixText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: value);
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState?.validate() == false) return;
    final text = _textController.value.text;
    Navigator.of(context).pop<String>(text);
  }

  Future<void> _handleReset() async {
    if (widget.resetValue == null) {
      return;
    }
    Navigator.of(context).pop<String>(widget.resetValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: title,
      actions: [
        if (widget.resetValue != null &&
            _textController.value.text != widget.resetValue) ...[
          TextButton(
            onPressed: _handleReset,
            child: Text(appLocalizations.reset),
          ),
        ] else
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(appLocalizations.cancel),
          ),
        TextButton(
          onPressed: _handleUpdate,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        autovalidateMode: widget.autovalidateMode,
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            TextFormField(
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
              obscureText: widget.obscureText ?? false,
              keyboardType: widget.keyboardType ?? TextInputType.url,
              maxLines: widget.obscureText == true ? 1 : 5,
              minLines: 1,
              controller: _textController,
              onFieldSubmitted: (_) {
                _handleUpdate();
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: suffixText,
                hintText: widget.hintText,
                labelText: widget.labelText,
              ),
              validator: widget.validator,
            ),
          ],
        ),
      ),
    );
  }
}

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
      final selected = isInCurrentRange
          ? _dragSelectionValue
          : _initialDragSelectedIds.contains(id);
      setDragSelected(id, selected);
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
      if ((Offset.zero & renderObject.size).contains(position)) {
        return index;
      }
    }
    return null;
  }
}

class _ListInputPageState extends ConsumerState<ListInputPage>
    with _DragSelectionMixin<ListInputPage> {
  List<String> _items = [];
  late List<String> _originItems;
  final _key = utils.id;

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

  Future<void> _handleAddOrEdit([String? item]) async {
    final appLocalizations = context.appLocalizations;
    String? uniqueValidator(String? value) {
      final index = _items.indexWhere((entry) {
        return entry == value;
      });
      final current = item == value;
      if (index != -1 && !current) {
        return appLocalizations.existsTip(appLocalizations.value);
      }
      return null;
    }

    final value = await globalState.showCommonDialog<String>(
      child: AddDialog(
        valueField: Field(
          label: widget.valueLabel ?? appLocalizations.value,
          value: item ?? '',
          validator: uniqueValidator,
        ),
        valueMaxLength: widget.itemMaxLength,
        title: item != null ? appLocalizations.edit : appLocalizations.add,
      ),
    );

    if (value == null) return;
    final index = _items.indexWhere((entry) {
      return entry == item;
    });
    final nextItems = List<String>.from(_items);
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
        .where((item) => !selectedItems.contains(item))
        .toList();
    _items = newItems;
    ref.read(itemsProvider(_key).notifier).value = {};
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (res != true) {
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
    final route = ModalRoute.of(context);
    if (route is CommonRoute) {
      route.updateCurrentResult(List<String>.from(_items));
    }
    return CommonPopScope(
      canPop: route is CommonRoute && selectedItems.isEmpty,
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
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (!stringListEquality.equals(_items, _originItems)) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
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
  final List<String> Function(String value)? valueParser;
  final String Function(List<String> values)? valueSerializer;

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
    this.valueParser,
    this.valueSerializer,
  }) : assert((valueParser == null) == (valueSerializer == null));

  @override
  ConsumerState<MapInputPage> createState() => _MapInputPageState();
}

class _MapInputPageState extends ConsumerState<MapInputPage>
    with _DragSelectionMixin<MapInputPage> {
  List<MapEntry<String, String>> _items = [];
  late final List<MapEntry<String, String>> _originItems;
  final _key = utils.id;

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

    if (widget.valueParser != null) {
      final value = await _showListValueDialog(item, uniqueValidator);
      if (value == null) return;
      _updateItem(item, value);
      return;
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

    final value = await globalState.showCommonDialog<MapEntry<String, String>>(
      child: AddDialog(
        keyField: keyField,
        valueField: valueField,
        keyMaxLength: widget.keyMaxLength,
        valueMaxLength: widget.valueMaxLength,
        title: item != null ? appLocalizations.edit : appLocalizations.add,
      ),
    );
    if (value == null) return;
    _updateItem(item, value);
  }

  Future<MapEntry<String, String>?> _showListValueDialog(
    MapEntry<String, String>? item,
    FormFieldValidator<String> uniqueValidator,
  ) async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState
        .showCommonDialog<MapEntry<String, List<String>>>(
          child: MapEntryListDialog(
            title: item != null ? appLocalizations.edit : appLocalizations.add,
            keyField: Field(
              label: widget.keyLabel ?? appLocalizations.key,
              value: item?.key ?? '',
              validator: uniqueValidator,
            ),
            values: item == null ? const [] : widget.valueParser!(item.value),
            valueLabel: widget.valueLabel ?? appLocalizations.value,
            keyMaxLength: widget.keyMaxLength,
            valueMaxLength: widget.valueMaxLength,
          ),
        );
    if (value == null) {
      return null;
    }
    return MapEntry(value.key, widget.valueSerializer!(value.value));
  }

  void _updateItem(
    MapEntry<String, String>? item,
    MapEntry<String, String> value,
  ) {
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
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (res != true) {
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
      key: ValueKey(value),
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
    final route = ModalRoute.of(context);
    if (route is CommonRoute) {
      route.updateCurrentResult(Map<String, String>.fromEntries(_items));
    }
    return CommonPopScope(
      canPop: route is CommonRoute && selectedItems.isEmpty,
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

class MapEntryListDialog extends StatefulWidget {
  final String title;
  final Field keyField;
  final List<String> values;
  final String valueLabel;
  final int? keyMaxLength;
  final int? valueMaxLength;

  const MapEntryListDialog({
    super.key,
    required this.title,
    required this.keyField,
    required this.values,
    required this.valueLabel,
    this.keyMaxLength,
    this.valueMaxLength,
  });

  @override
  State<MapEntryListDialog> createState() => _MapEntryListDialogState();
}

class _MapEntryListDialogState extends State<MapEntryListDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  final List<TextEditingController> _valueControllers = [];
  final List<FocusNode> _valueFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.keyField.value);
    final values = widget.values.isEmpty ? const [''] : widget.values;
    for (final value in values) {
      _valueControllers.add(TextEditingController(text: value));
      _valueFocusNodes.add(FocusNode());
    }
  }

  void _addValue() {
    setState(() {
      _valueControllers.add(TextEditingController());
      _valueFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _valueFocusNodes.last.requestFocus();
    });
  }

  void _removeValue(int index) {
    if (_valueControllers.length == 1) {
      _valueControllers.single.clear();
      _valueFocusNodes.single.requestFocus();
      return;
    }
    setState(() {
      _valueControllers.removeAt(index).dispose();
      _valueFocusNodes.removeAt(index).dispose();
    });
  }

  void _handleValueSubmitted(int index) {
    if (index == _valueControllers.length - 1) {
      _addValue();
      return;
    }
    _valueFocusNodes[index + 1].requestFocus();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop<MapEntry<String, List<String>>>(
      MapEntry(
        _keyController.text,
        _valueControllers.map((controller) => controller.text).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    for (final controller in _valueControllers) {
      controller.dispose();
    }
    for (final focusNode in _valueFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.title,
      maxWidth: 360,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _addValue,
                icon: const Icon(Icons.add),
                label: Text(appLocalizations.add),
              ),
              const Spacer(),
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: Text(appLocalizations.cancel),
              ),
              TextButton(
                onPressed: _submit,
                child: Text(appLocalizations.confirm),
              ),
            ],
          ),
        ),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              autofocus: true,
              controller: _keyController,
              maxLines: 3,
              minLines: 1,
              inputFormatters: widget.keyMaxLength == null
                  ? null
                  : TextInputLimits.limit(widget.keyMaxLength!),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: widget.keyField.label,
              ),
              onFieldSubmitted: (_) {
                _valueFocusNodes.first.requestFocus();
              },
              validator: (value) {
                final validationError = widget.keyField.validator?.call(value);
                if (validationError != null) return validationError;
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(widget.keyField.label);
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < _valueControllers.length; index++) ...[
              TextFormField(
                controller: _valueControllers[index],
                focusNode: _valueFocusNodes[index],
                inputFormatters: widget.valueMaxLength == null
                    ? null
                    : TextInputLimits.limit(widget.valueMaxLength!),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: widget.valueLabel,
                  suffixIcon: IconButton(
                    tooltip: appLocalizations.delete,
                    onPressed: () => _removeValue(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
                onFieldSubmitted: (_) {
                  _handleValueSubmitted(index);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip(widget.valueLabel);
                  }
                  return null;
                },
              ),
              if (index < _valueControllers.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class AddDialog extends StatefulWidget {
  final String title;
  final Field? keyField;
  final Field valueField;
  final int? keyMaxLength;
  final int? valueMaxLength;

  const AddDialog({
    super.key,
    required this.title,
    this.keyField,
    required this.valueField,
    this.keyMaxLength,
    this.valueMaxLength,
  });

  @override
  State<AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<AddDialog> {
  TextEditingController? _keyController;
  late TextEditingController _valueController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Field? get keyField => widget.keyField;

  Field get valueField => widget.valueField;

  @override
  void initState() {
    super.initState();
    if (keyField != null) {
      _keyController = TextEditingController(text: keyField!.value);
    }
    _valueController = TextEditingController(text: valueField.value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (keyField != null) {
      Navigator.of(context).pop<MapEntry<String, String>>(
        MapEntry(_keyController!.text, _valueController.text),
      );
    } else {
      Navigator.of(context).pop<String>(_valueController.text);
    }
  }

  @override
  void dispose() {
    _keyController?.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.title,
      actions: [
        TextButton(onPressed: _submit, child: Text(appLocalizations.confirm)),
      ],
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: _formKey,
        child: Wrap(
          runSpacing: 16,
          children: [
            if (keyField != null)
              TextFormField(
                maxLines: 3,
                minLines: 1,
                inputFormatters: widget.keyMaxLength == null
                    ? null
                    : TextInputLimits.limit(widget.keyMaxLength!),
                controller: _keyController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: keyField!.label,
                ),
                validator: (String? value) {
                  String? res;
                  if (keyField!.validator != null) {
                    res = keyField!.validator!(value);
                  }
                  if (res != null) {
                    return res;
                  }
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip(appLocalizations.key);
                  }
                  return null;
                },
              ),
            TextFormField(
              maxLines: 3,
              minLines: 1,
              inputFormatters: widget.valueMaxLength == null
                  ? null
                  : TextInputLimits.limit(widget.valueMaxLength!),
              keyboardType: TextInputType.text,
              controller: _valueController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: valueField.label,
              ),
              onFieldSubmitted: (_) {
                _submit();
              },
              validator: (String? value) {
                String? res;
                if (valueField.validator != null) {
                  res = valueField.validator!(value);
                }
                if (res != null) {
                  return res;
                }
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(appLocalizations.value);
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NoInputBorder extends InputBorder {
  const NoInputBorder() : super(borderSide: BorderSide.none);

  @override
  NoInputBorder copyWith({BorderSide? borderSide}) => const NoInputBorder();

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  NoInputBorder scale(double t) => const NoInputBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRect(rect, paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {}
}
