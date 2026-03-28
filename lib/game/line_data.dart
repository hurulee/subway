import 'package:flutter/material.dart';

class LineInfo {
  final String label;
  final String assetPath;
  final Color  bg;
  final Color  fg;

  const LineInfo(this.label, this.assetPath, this.bg, this.fg);
}

const kLines = <LineInfo>[
  // IRT Broadway–7th Av (red)
  LineInfo('1', 'assets/data/nyc/1_train.json', Color(0xFFEE352E), Colors.white),
  LineInfo('2', 'assets/data/nyc/2_train.json', Color(0xFFEE352E), Colors.white),
  LineInfo('3', 'assets/data/nyc/3_train.json', Color(0xFFEE352E), Colors.white),
  // IRT Lexington (green)
  LineInfo('4', 'assets/data/nyc/4_train.json', Color(0xFF00933C), Colors.white),
  LineInfo('5', 'assets/data/nyc/5_train.json', Color(0xFF00933C), Colors.white),
  LineInfo('6', 'assets/data/nyc/6_train.json', Color(0xFF00933C), Colors.white),
  // IRT Flushing (purple)
  LineInfo('7', 'assets/data/nyc/7_train.json', Color(0xFFB933AD), Colors.white),
  // IND 8th Av (blue)
  LineInfo('A', 'assets/data/nyc/a_train.json', Color(0xFF0039A6), Colors.white),
  LineInfo('C', 'assets/data/nyc/c_train.json', Color(0xFF0039A6), Colors.white),
  LineInfo('E', 'assets/data/nyc/e_train.json', Color(0xFF0039A6), Colors.white),
  // IND 6th Av (orange)
  LineInfo('B', 'assets/data/nyc/b_train.json', Color(0xFFFF6319), Colors.white),
  LineInfo('D', 'assets/data/nyc/d_train.json', Color(0xFFFF6319), Colors.white),
  LineInfo('F', 'assets/data/nyc/f_train.json', Color(0xFFFF6319), Colors.white),
  LineInfo('M', 'assets/data/nyc/m_train.json', Color(0xFFFF6319), Colors.white),
  // IND Crosstown (lime)
  LineInfo('G', 'assets/data/nyc/g_train.json', Color(0xFF6CBE45), Colors.black),
  // BMT Jamaica (brown)
  LineInfo('J', 'assets/data/nyc/j_train.json', Color(0xFF996633), Colors.white),
  LineInfo('Z', 'assets/data/nyc/z_train.json', Color(0xFF996633), Colors.white),
  // BMT Canarsie (grey)
  LineInfo('L', 'assets/data/nyc/l_train.json', Color(0xFFA7A9AC), Colors.black),
  // BMT Broadway (yellow)
  LineInfo('N', 'assets/data/nyc/n_train.json', Color(0xFFFCCC0A), Colors.black),
  LineInfo('Q', 'assets/data/nyc/q_train.json', Color(0xFFFCCC0A), Colors.black),
  LineInfo('R', 'assets/data/nyc/r_train.json', Color(0xFFFCCC0A), Colors.black),
  LineInfo('W', 'assets/data/nyc/w_train.json', Color(0xFFFCCC0A), Colors.black),
  // Shuttles (dark grey)
  LineInfo('S\n42', 'assets/data/nyc/s_m_train.json', Color(0xFF808183), Colors.white),
  LineInfo('S\nFk', 'assets/data/nyc/s_b_train.json', Color(0xFF808183), Colors.white),
  LineInfo('S\nRk', 'assets/data/nyc/s_q_train.json', Color(0xFF808183), Colors.white),
];
