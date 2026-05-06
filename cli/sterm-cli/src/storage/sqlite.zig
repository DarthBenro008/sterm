pub const database_path = "~/.sterm/state/sterm.db";
pub const integration_status = "sqlite3-unlinked";
pub const compiled = false;

pub const SqliteError = error{
    SqliteUnavailable,
};

pub fn requireAvailable() SqliteError!void {
    return SqliteError.SqliteUnavailable;
}
