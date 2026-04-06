/// Sealed class representing the result of an API call.
/// Either [Success] with data, or [Failure] with an error message.
sealed class ApiResult<T> {
  const ApiResult();

  /// Creates a success result.
  const factory ApiResult.success(T data) = Success<T>;

  /// Creates a failure result.
  const factory ApiResult.failure(String message, {int? statusCode}) =
      Failure<T>;

  /// Pattern-matches on the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode) failure,
  }) {
    final self = this;
    if (self is Success<T>) {
      return success(self.data);
    } else if (self is Failure<T>) {
      return failure(self.message, self.statusCode);
    }
    throw StateError('Unhandled ApiResult type');
  }

  /// Returns the data if success, otherwise null.
  T? get dataOrNull {
    final self = this;
    if (self is Success<T>) return self.data;
    return null;
  }

  /// Returns true if this is a success result.
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result.
  bool get isFailure => this is Failure<T>;
}

/// Represents a successful API response with [data].
class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'ApiResult.success($data)';
}

/// Represents a failed API response with a [message] and optional [statusCode].
class Failure<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(message, statusCode);

  @override
  String toString() => 'ApiResult.failure($message, statusCode: $statusCode)';
}
