#include <Python.h>

PyGILState_STATE PyGILState_Ensure(void);
void PyGILState_Release(PyGILState_STATE);