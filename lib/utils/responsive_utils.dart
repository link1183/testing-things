import 'package:flutter/material.dart';

int calculateGridColumns(BuildContext context,
    {GridType type = GridType.standard}) {
  final width = MediaQuery.of(context).size.width;

  switch (type) {
    case GridType.dense:
      if (width > 1200) return 6;
      if (width > 900) return 5;
      if (width > 600) return 4;
      return 3;

    case GridType.collection:
      if (width > 1200) return 5;
      if (width > 900) return 4;
      if (width > 600) return 3;
      return 2;

    case GridType.standard:
    default:
      if (width > 1200) return 5;
      if (width > 900) return 4;
      if (width > 600) return 3;
      return 2;
  }
}

enum GridType {
  standard,
  dense,
  collection,
}
