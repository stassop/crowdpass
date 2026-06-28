import 'package:flutter/material.dart';

import 'package:crowdpass/models/unit_value.dart' show Unit;

class UnitMenu<T extends Unit> extends StatelessWidget {
  /// The currently selected unit to display.
  final T selectedUnit;

  /// The list of available units to populate the dropdown.
  final List<T> units;

  /// Callback fired when a user selects a unit from the menu.
  final ValueChanged<T> onUnitChanged;

  /// Determines if the menu can be opened. 
  final bool isEditable;

  /// Optional text style for the selected unit's symbol.
  final TextStyle? textStyle;

  const UnitMenu({
    super.key,
    required this.selectedUnit,
    required this.units,
    required this.onUnitChanged,
    this.isEditable = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return InkWell(
          // Only toggle the menu if the widget is set to editable
          onTap: isEditable 
              ? () => controller.isOpen ? controller.close() : controller.open() 
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 0, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min, // Takes only necessary width
              children: [
                Text(
                  selectedUnit.symbol,
                  style: textStyle ?? Theme.of(context).textTheme.bodyLarge,
                ),
                // Optionally hide the arrow if it's not editable to visually indicate state
                if (isEditable) 
                  const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      },
      menuChildren: units.map((unit) {
        return MenuItemButton(
          onPressed: () => onUnitChanged(unit),
          child: Text('${unit.name} (${unit.symbol})'),
        );
      }).toList(),
    );
  }
}