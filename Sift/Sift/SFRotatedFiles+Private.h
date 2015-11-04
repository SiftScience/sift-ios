// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * Private methods of `SFRotatedFiles`.
 *
 * You must acquire respective locks before calling these methods.
 */
@interface SFRotatedFiles ()

/**
 * Create and open the current file, and then seek to the end.
 *
 * @return nil on failure.
 */
- (NSFileHandle *)currentFile;

/** Close the current file and set the file handle `_currentFile` to nil. */
- (void)closeCurrentFile;

/** @return the list file paths of non-current files. */
- (NSArray *)filePaths;

/** @return index for non-current files, or -1 for the current file. */
- (int)fileIndex:(NSString *)fileName;

@end
