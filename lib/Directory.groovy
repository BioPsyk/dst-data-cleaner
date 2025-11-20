/**
 * This class exists to enable the distinction of file and directory on type level.
 * This is useful if you want to strictly control whether a function accepts a file or a directory.
 */
class Directory extends File {
  Directory(String pathname) {
    super(pathname)
  }
}
