Tôi thấy rõ 6 issues:



1\. \*\*`exceptions.dart:3`\*\* — `dangling\_library\_doc\_comments`: Doc comment ở dòng 1-3 không gắn vào declaration nào (dòng 4 trống)

2\. \*\*`failures.dart:3`\*\* — `unintended\_html\_in\_doc\_comment`: `Either<Failure, T>` 

3\. \*\*`constants.dart:1`\*\* — `dangling\_library\_doc\_comments`: Doc comment dòng 1 rồi dòng 2 trống

4\. \*\*`typedef.dart:4,7`\*\* — `unintended\_html\_in\_doc\_comment`: `Either<Failure, T>` và `Either<Failure, void>`

5\. \*\*`translate\_text\_usecase.dart:9`\*\* — `unintended\_html\_in\_doc\_comment`: `UseCase<T, P>`

✅ \*\*No issues found!\*\* Tất cả 6 issues đã được sửa:



| File | Issue | Fix |

|---|---|---|

| `exceptions.dart` | `dangling\_library\_doc\_comments` | Chuyển `///` → `//` (comment thường, không phải doc comment) |

| `failures.dart` | `unintended\_html\_in\_doc\_comment` | Bọc `Either<Failure, T>` trong backticks |

| `constants.dart` | `dangling\_library\_doc\_comments` | Chuyển `///` → `//` + thêm doc comment gắn trực tiếp vào class |

| `typedef.dart` (x2) | `unintended\_html\_in\_doc\_comment` | Bọc generic types trong backticks |

| `translate\_text\_usecase.dart` | `unintended\_html\_in\_doc\_comment` | Bọc `UseCase<T, P>` trong backticks |

