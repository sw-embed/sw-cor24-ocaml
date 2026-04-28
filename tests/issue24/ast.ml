type node = AAtom of string | AGroup of string * string list | AStmt of string * string list | AProgram of string list | AError of string
