class Book {
  final int id;
  final int year;
  final String title;
  final String handle;
  final String publisher;
  final String isbn;
  final int pages;
  final List<String> notes;
  final String createdAt;
  final List<Villain> villains;

  Book({
    required this.id,
    required this.year,
    required this.title,
    required this.handle,
    required this.publisher,
    required this.isbn,
    required this.pages,
    required this.notes,
    required this.createdAt,
    required this.villains,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      year: json['Year'] ?? 0,
      title: json['Title'] ?? '',
      handle: json['handle'] ?? '',
      publisher: json['Publisher'] ?? '',
      isbn: json['ISBN'] ?? '',
      pages: json['Pages'] ?? 0,
      notes: List<String>.from(json['Notes'] ?? []),
      createdAt: json['created_at'] ?? '',
      villains: (json['villains'] as List<dynamic>? ?? [])
          .map((villain) => Villain.fromJson(villain))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'Year': year,
      'Title': title,
      'handle': handle,
      'Publisher': publisher,
      'ISBN': isbn,
      'Pages': pages,
      'Notes': notes,
      'created_at': createdAt,
      'villains': villains.map((villain) => villain.toJson()).toList(),
    };
  }
}

class Villain {
  final String name;
  final String url;

  Villain({
    required this.name,
    required this.url,
  });

  factory Villain.fromJson(Map<String, dynamic> json) {
    return Villain(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }
}

class BooksResponse {
  final List<Book> data;

  BooksResponse({required this.data});

  factory BooksResponse.fromJson(Map<String, dynamic> json) {
    return BooksResponse(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((book) => Book.fromJson(book))
          .toList(),
    );
  }
}

class BookResponse {
  final Book data;

  BookResponse({required this.data});

  factory BookResponse.fromJson(Map<String, dynamic> json) {
    return BookResponse(
      data: Book.fromJson(json['data']),
    );
  }
}