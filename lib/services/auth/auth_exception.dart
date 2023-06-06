//Login Exception
class UserNoteFoundAuthException implements Exception {}

class WrongPasswordAuthException implements Exception {}

//Register Exception
class WeakPasswordAuthException implements Exception {}

class EmailAlreadyInUserAuthException implements Exception {}

class InvalidEmailAuthException implements Exception {}

//Generic Exceptiom
class GenericAuthException implements Exception {}

class UserNoteLoggedInAuthException implements Exception {}
