class CloudStorageException implements Exception {
  const CloudStorageException();
}

class CouldNoteCreateNoteException extends CloudStorageException {}

class CouldNoteGetAllNotesException extends CloudStorageException {}

class CouldNoteUpdateNotesException extends CloudStorageException {}

class CouldNoteDeleteNotesException extends CloudStorageException {}
