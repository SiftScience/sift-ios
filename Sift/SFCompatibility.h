// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

#if __has_feature(objc_generics)
#define SF_GENERICS(class, ...) class<__VA_ARGS__>
#define SF_GENERICS_TYPE(type) type
#else
#define SF_GENERICS(class, ...) class
#define SF_GENERICS_TYPE(type) id
#endif
