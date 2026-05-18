import 'package:flutter/material.dart';

import '../models/die.dart';

class DieSelector extends StatelessWidget {
  const DieSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DieType selected;
  final ValueChanged<DieType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: DieType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final die = DieType.values[i];
          final isSel = die == selected;
          return ChoiceChip(
            label: Text(die.label),
            selected: isSel,
            onSelected: (_) => onChanged(die),
            labelStyle: TextStyle(
              color: isSel ? Colors.black : const Color(0xFFCED3D9),
              fontWeight: FontWeight.w600,
            ),
            selectedColor: const Color(0xFFCED3D9),
            backgroundColor: const Color(0xFF26292D),
            side: const BorderSide(color: Color(0xFF3A3E43)),
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}
