/// Result codes returned by `libgrafile`.
///
/// The numbering reuses SQLite's code space where the classes overlap.
abstract final class GrafileResult {
  /// Success.
  static const int ok = 0;

  /// Generic failure: syntax errors, unsupported features.
  static const int error = 1;

  /// Internal invariant failure or panic.
  static const int internal = 2;

  /// The database is locked by another writer.
  static const int busy = 5;

  /// A lock request conflicts with locks held elsewhere.
  static const int locked = 6;

  /// A write was attempted on a read-only database.
  static const int readOnly = 8;

  /// Operating-system I/O failure.
  static const int ioError = 10;

  /// On-disk structure failed validation.
  static const int corrupt = 11;

  /// A referenced entity does not exist.
  static const int notFound = 12;

  /// A value is out of range.
  static const int tooBig = 18;

  /// A uniqueness constraint was violated.
  static const int constraint = 19;

  /// A value has the wrong type for the requested accessor.
  static const int mismatch = 20;

  /// The API was misused (null pointers, wrong state).
  static const int misuse = 21;

  /// The file is not a grafile database.
  static const int notADatabase = 26;

  /// `grafile_step` produced a row.
  static const int row = 100;

  /// `grafile_step` finished.
  static const int done = 101;
}

/// Open flags for `grafile_open_v2`.
abstract final class GrafileOpenFlags {
  /// Open an existing database read-only.
  static const int readOnly = 0x1;

  /// Open read/write (the file must exist).
  static const int readWrite = 0x2;

  /// Create the file when missing.
  static const int create = 0x4;
}

/// Column kinds returned by `grafile_column_kind`.
abstract final class GrafileColumnKind {
  /// `null`.
  static const int nullValue = 0;

  /// Integer.
  static const int integer = 1;

  /// Floating-point number.
  static const int float = 2;

  /// String.
  static const int text = 3;

  /// Bytes.
  static const int blob = 4;

  /// Boolean.
  static const int boolean = 5;

  /// List.
  static const int list = 6;

  /// Map.
  static const int map = 7;

  /// Node reference.
  static const int node = 8;

  /// Relationship reference.
  static const int edge = 9;

  /// Date, exposed as ISO 8601 text.
  static const int date = 10;

  /// Local time.
  static const int localTime = 11;

  /// Time with a fixed UTC offset.
  static const int time = 12;

  /// Local date and time.
  static const int localDateTime = 13;

  /// Date and time with an offset and optional IANA zone.
  static const int dateTime = 14;

  /// Duration.
  static const int duration = 15;

  /// Point, exposed as a `{"srid", "x", "y"[, "z"]}` object.
  static const int point = 16;
}
