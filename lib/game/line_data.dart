import 'package:flutter/material.dart';

enum LineGroup { short, medium, long }

class LineInfo {
  final String label;
  final String assetPath;
  final Color  bg;
  final Color  fg;
  final LineGroup group;

  const LineInfo(this.label, this.assetPath, this.bg, this.fg, this.group);
}

const kLines = <LineInfo>[
  // IRT Broadway–7th Av (red) — long (38 stations)
  LineInfo('1', 'assets/data/nyc/1_train.json', Color(0xFFEE352E), Colors.white, LineGroup.long),
  LineInfo('2', 'assets/data/nyc/2_train.json', Color(0xFFEE352E), Colors.white, LineGroup.long),
  LineInfo('3', 'assets/data/nyc/3_train.json', Color(0xFFEE352E), Colors.white, LineGroup.medium),
  // IRT Lexington (green)
  LineInfo('4', 'assets/data/nyc/4_train.json', Color(0xFF00933C), Colors.white, LineGroup.medium),
  LineInfo('5', 'assets/data/nyc/5_train.json', Color(0xFF00933C), Colors.white, LineGroup.medium),
  LineInfo('6', 'assets/data/nyc/6_train.json', Color(0xFF00933C), Colors.white, LineGroup.long),
  // IRT Flushing (purple) — short (22 stations)
  LineInfo('7', 'assets/data/nyc/7_train.json', Color(0xFFB933AD), Colors.white, LineGroup.short),
  // IND 8th Av (blue)
  LineInfo('A', 'assets/data/nyc/a_train.json', Color(0xFF0039A6), Colors.white, LineGroup.long),
  LineInfo('C', 'assets/data/nyc/c_train.json', Color(0xFF0039A6), Colors.white, LineGroup.long),
  LineInfo('E', 'assets/data/nyc/e_train.json', Color(0xFF0039A6), Colors.white, LineGroup.short),
  // IND 6th Av (orange)
  LineInfo('B', 'assets/data/nyc/b_train.json', Color(0xFFFF6319), Colors.white, LineGroup.long),
  LineInfo('D', 'assets/data/nyc/d_train.json', Color(0xFFFF6319), Colors.white, LineGroup.medium),
  LineInfo('F', 'assets/data/nyc/f_train.json', Color(0xFFFF6319), Colors.white, LineGroup.long),
  LineInfo('M', 'assets/data/nyc/m_train.json', Color(0xFFFF6319), Colors.white, LineGroup.medium),
  // IND Crosstown (lime) — short (21 stations)
  LineInfo('G', 'assets/data/nyc/g_train.json', Color(0xFF6CBE45), Colors.black, LineGroup.short),
  // BMT Jamaica (brown)
  LineInfo('J', 'assets/data/nyc/j_train.json', Color(0xFF996633), Colors.white, LineGroup.medium),
  LineInfo('Z', 'assets/data/nyc/z_train.json', Color(0xFF996633), Colors.white, LineGroup.short),
  // BMT Canarsie (grey) — short (24 stations)
  LineInfo('L', 'assets/data/nyc/l_train.json', Color(0xFFA7A9AC), Colors.black, LineGroup.short),
  // BMT Broadway (yellow)
  LineInfo('N', 'assets/data/nyc/n_train.json', Color(0xFFFCCC0A), Colors.black, LineGroup.medium),
  LineInfo('Q', 'assets/data/nyc/q_train.json', Color(0xFFFCCC0A), Colors.black, LineGroup.medium),
  LineInfo('R', 'assets/data/nyc/r_train.json', Color(0xFFFCCC0A), Colors.black, LineGroup.long),
  LineInfo('W', 'assets/data/nyc/w_train.json', Color(0xFFFCCC0A), Colors.black, LineGroup.short),
];

List<LineInfo> linesForGroup(LineGroup group) =>
    kLines.where((l) => l.group == group).toList();
