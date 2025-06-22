import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';

class BookService {
  static const String baseUrl = 'https://stephen-king-api.onrender.com/api';
  
  // Get all books
  static Future<List<Book>> getAllBooks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/books'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final BooksResponse booksResponse = BooksResponse.fromJson(jsonData);
        return booksResponse.data;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching books: $e');
    }
  }

  // Get book by ID
  static Future<Book> getBookById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/book/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final BookResponse bookResponse = BookResponse.fromJson(jsonData);
        return bookResponse.data;
      } else {
        throw Exception('Failed to load book: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching book: $e');
    }
  }

  // Search books by title
  static Future<List<Book>> searchBooks(String query) async {
    try {
      final books = await getAllBooks();
      return books.where((book) => 
        book.title.toLowerCase().contains(query.toLowerCase()) ||
        book.publisher.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      throw Exception('Error searching books: $e');
    }
  }

  // Get books by year range
  static Future<List<Book>> getBooksByYearRange(int startYear, int endYear) async {
    try {
      final books = await getAllBooks();
      return books.where((book) => 
        book.year >= startYear && book.year <= endYear
      ).toList();
    } catch (e) {
      throw Exception('Error filtering books by year: $e');
    }
  }

  // Get books sorted by year
  static Future<List<Book>> getBooksSortedByYear({bool ascending = true}) async {
    try {
      final books = await getAllBooks();
      books.sort((a, b) => ascending ? a.year.compareTo(b.year) : b.year.compareTo(a.year));
      return books;
    } catch (e) {
      throw Exception('Error sorting books: $e');
    }
  }

  // Get books sorted by title
  static Future<List<Book>> getBooksSortedByTitle({bool ascending = true}) async {
    try {
      final books = await getAllBooks();
      books.sort((a, b) => ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
      return books;
    } catch (e) {
      throw Exception('Error sorting books: $e');
    }
  }
}