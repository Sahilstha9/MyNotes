import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mynotes/extensions/list/filter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'crud_exceptions.dart';

class NotesService {
  Database? _db;
  List<DatabaseNote> _notes = [];
  DatabaseUser? _user;

  static final NotesService _shared = NotesService._sharedInstances();
  NotesService._sharedInstances() {
    _notesStreamController =
        StreamController<List<DatabaseNote>>.broadcast(onListen: () {
      _notesStreamController.sink.add(_notes);
    });
  }
  factory NotesService() => _shared;

  late final StreamController<List<DatabaseNote>> _notesStreamController;

  Stream<List<DatabaseNote>> get allNotes =>
      _notesStreamController.stream.filter((note) {
        final currentUser = _user;
        if (currentUser != null) {
          return note.userId == currentUser.id;
        } else {
          throw UserShouldBeSetBeforeReadingAllNotes();
        }
      });

  Future<DatabaseUser> getOrCreateUser(
      {required String email, bool setAsCurrentUser = true}) async {
    try {
      final user = await getUser(email: email);
      if (setAsCurrentUser) {
        _user = user;
      }
      return user;
    } on CouldNotFindUser {
      final createdUser = await createUser(email: email);
      if (setAsCurrentUser) {
        _user = createdUser;
      }
      return createUser(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cacheNotes() async {
    final allNotes = await getAllNote();
    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Future<int> deleteAllNotes() async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();
    final numberOfDeletion = await db.delete(noteTable);

    _notes = [];
    _notesStreamController.add(_notes);
    return numberOfDeletion;
  }

  Future<DatabaseNote> getNote({required int id}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();
    final notes = await db.query(
      noteTable,
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (notes.isEmpty) {
      throw CouldNotFindNote();
    } else {
      final note = DatabaseNote.fromRow(notes.first);

      _notes.removeWhere((element) => element.id == id);
      _notes.add(note);
      _notesStreamController.add(_notes);
      return note;
    }
  }

  Future<DatabaseNote> updateNote(
      {required DatabaseNote note, required String text}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    await getNote(id: note.id);

    final updatesCount = await db.update(
      noteTable,
      {
        textColumn: text,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );

    if (updatesCount == 0) {
      throw CouldNotUpdateNote();
    } else {
      final updatedNote = await getNote(id: note.id);
      _notes.removeWhere((element) => element.id == updatedNote.id);
      _notes.add(updatedNote);
      _notesStreamController.add(_notes);

      return updatedNote;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNote() async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();
    final notes = await db.query(
      noteTable,
    );

    return notes.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  Future<void> deleteNote({required int id}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    final deleteCount = await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deleteCount != 1) {
      throw CouldNotDeleteNote();
    } else {
      _notes.removeWhere((element) => element.id == id);
      _notesStreamController.add(_notes);
    }
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    final results = await db.query(userTable,
        limit: 1, where: 'email = ?', whereArgs: [email.toLowerCase()]);

    if (results.isEmpty) {
      throw CouldNotFindUser();
    } else {
      return DatabaseUser.fromRow(results.first);
    }
  }

  Database _getDatabaseorThrow() {
    final db = _db;
    if (db == null) {
      throw DatabaseNotOpen();
    } else {
      return db;
    }
  }

  Future<void> _ensureDbIsOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {
      //
    }
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }

    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);

      _db = db;
      await db.execute(createUserTable);
      await db.execute(createNoteTable);
      await _cacheNotes();
    } on MissingPlatformDirectoryException {
      throw UnableToGetDatabaseDirectory();
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DatabaseNotOpen();
    } else {
      await db.close();
      _db = null;
    }
  }

  Future<void> deleteUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    final deleteCount = await db.delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (deleteCount != 1) {
      throw CouldNotDeleteUser();
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    final results = await db.query(userTable,
        limit: 1, where: 'email = ?', whereArgs: [email.toLowerCase()]);

    if (results.isNotEmpty) {
      throw UserAlreadyExists();
    }

    final userId = await db.insert(userTable, {
      emailColumn: email.toLowerCase(),
    });

    return DatabaseUser(id: userId, email: email);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureDbIsOpen();
    final db = _getDatabaseorThrow();

    final dbUser = await getUser(email: owner.email);

    if (dbUser != owner) {
      throw CouldNotFindUser();
    }

    const text = '';

    final noteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: text,
    });

    final note = DatabaseNote(id: noteId, userId: owner.id, text: text);
    _notes.add(note);
    _notesStreamController.add(_notes);
    return note;
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({
    required this.id,
    required this.email,
  });

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'Person, ID = $id, email = $email';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class DatabaseNote {
  final int id;
  final int userId;
  final String text;

  const DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String;

  @override
  String toString() => 'Note, ID = $id, userId = $userId, text = $text';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'notes.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = "id";
const emailColumn = "email";
const userIdColumn = "user_id";
const textColumn = "text";

const createUserTable = '''CREATE TABLE IF NOT EXISTS "user" (
                                  "id"	INTEGER UNIQUE,
                                  "email"	TEXT NOT NULL UNIQUE,
                                  PRIMARY KEY("id" AUTOINCREMENT)
                                );''';

const createNoteTable = '''CREATE TABLE IF NOT EXISTS "note" (
	"id"	INTEGER,
	"user_id"	INTEGER NOT NULL,
	"text"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT),
	FOREIGN KEY("user_id") REFERENCES "user"("id")
);''';
