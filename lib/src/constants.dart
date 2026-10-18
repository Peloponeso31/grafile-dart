/// Result codes returned by `libgrafile`.
///
/// The numbering reuses SQLite's code space where the classes overlap.
abstract final class GrafileResult {
  static const int ok = 0;
  static const int error = 1;
  static const int internal = 2;
  static const int busy = 5;
  static const int locked = 6;
  static const int readOnly = 8;
  static const int ioError = 10;
  static const int corrupt = 11;
  static const int notFound = 12;
  static const int tooBig = 18;
  static const int constraint = 19;
  static const int mismatch = 20;
  static const int misuse = 21;
  static const int notADatabase = 26;
  static const int row = 100;
  static const int done = 101;
}

/// Open flags for `grafile_open_v2`.
abstract final class GrafileOpenFlags {
  static const int readOnly = 0x1;
  static const int readWrite = 0x2;
  static const int create = 0x4;
}

/// Column kinds returned by `grafile_column_kind`.
abstract final class GrafileColumnKind {
  static const int nullValue = 0;
  static const int integer = 1;
  static const int float = 2;
  static const int text = 3;
  static const int blob = 4;
  static const int boolean = 5;
  static const int list = 6;
  static const int map = 7;
  static const int node = 8;
  static const int edge = 9;
  static const int date = 10;
  static const int localTime = 11;
  static const int time = 12;
  static const int localDateTime = 13;
  static const int dateTime = 14;
  static const int duration = 15;
  static const int point = 16;
}
