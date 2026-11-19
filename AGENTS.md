# Rules for contributions to this repository

* New development happens on the `main` branch first, not `release` branches.
* Do not manually wrap comments or code at 80 characters (or any other arbitrary limit).
* Keep tests as focused as possible on the issue. Do not use internal/private functions if possible - the test should be verifying the public interface of the library.
* Do not write comments about how something "used to be" before your change. Focus comments on explanations of things which are not obvious from the code. If the comment does not add real value to a human reader, delete it. History is available in source control.
