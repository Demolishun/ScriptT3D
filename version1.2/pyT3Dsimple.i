/*
//-----------------------------------------------------------------------------
// scriptT3D
// Copyright Demolishun Consulting (Frank Carney) 2012
//-----------------------------------------------------------------------------
*/
/* File: pyT3D.i */

/*
This is a contributing file and not meant to be parsed by SWIG directly.
This file is included in "scriptT3D.i".  Run SWIG against "scriptT3D.i" instead.
*/

// global data for all objects
%pythoncode %{
%}

// convert types
%typemap(in) S32,U32 {
    if (!PyInt_Check($input)) {
      PyErr_SetString(PyExc_TypeError, "Need an integer!");
      return NULL;
   }
   
   $1 = PyInt_AsLong($input);
}

%typemap(out) S32,U32 {
    $result = PyInt_FromLong($1);
}

%typecheck(SWIG_TYPECHECK_INTEGER)
   S32,U32
{
   $1 = (PyInt_Check($input) || PyLong_Check($input)) ? 1 : 0;
}

// Grab a Python function object as a Python object.
%typemap(in) PyObject *pyfunc {
  if (!PyCallable_Check($input)) {
      PyErr_SetString(PyExc_TypeError, "Need a callable object!");
      return NULL;
  }
  $1 = $input;
}

// Type mapping for grabbing a FILE * from Python
%typemap(in) FILE * {
  if (!PyFile_Check($input)) {
      PyErr_SetString(PyExc_TypeError, "Need a file!");
      return NULL;
  }
  $1 = PyFile_AsFile($input);
}

// This tells SWIG to treat char ** as a special case
%typemap(in) char ** {
  /* Check if is a list */
  if (PyList_Check($input)) {
    int size = PyList_Size($input);
    int i = 0;
    $1 = (char **) malloc((size+1)*sizeof(char *));
    for (i = 0; i < size; i++) {
      PyObject *o = PyList_GetItem($input,i);
      if (PyString_Check(o))
       $1[i] = PyString_AsString(PyList_GetItem($input,i));
      else {
       PyErr_SetString(PyExc_TypeError,"list must contain strings");
       free($1);
       return NULL;
      }
    }
    $1[i] = 0;
  } else {
    PyErr_SetString(PyExc_TypeError,"not a list");
    return NULL;
  }
}

// This cleans up the char ** array we malloc'd before the function call
%typemap(freearg) char ** {
  free((char *) $1);
}

// native python code
%pythoncode %{
# make FunctionCaller
def makeFunctionCallerLambda(name, sobj=None, noself=True):
   if sobj is None:
      #print "makeFunctionCallerLamba - no object", sobj, name
      fcObject = FunctionCaller(name)
      if noself:
         return lambda *args: fcObject.Call(len(args) or 0, map(str,args))
      else:
         return lambda self,*args: fcObject.Call(len(args) or 0, map(str,args))
   else:
      #print "makeFunctionCallerLamba - object", sobj, name
      fcObject = FunctionCaller(getSimObject(sobj), name)
      if noself:
         return lambda *args: fcObject.ObjectCall(len(args) or 0, map(str,args))
      else:
         return lambda self,*args: fcObject.ObjectCall(len(args) or 0, map(str,args))
   
# Console function interface class
class __Con(object):
   def __init__(self):
      self.Exec = makeFunctionCallerLambda("exec")
   # Hack to force this attribute to be name "Exec".  Python does not like this object to have an attribute names "exec".
   #Exec = makeFunctionCallerLambda("exec", noself=False)
   def __getattr__(self, name):
      # lookup function and return callable object
      # this will only happen once, after that the name is an attribute on the object
      #print "Con::Assigning attribute:",name
      name = str(name).lower()  # save space in lookup dictionary
      if isFunction(None, name):
         #fcObject = FunctionCaller(name)
         #setattr(self, name, lambda *args: fcObject.Call(len(args) or 0, map(str,args)))
         setattr(self, name, makeFunctionCallerLambda(name, noself=True))
         return getattr(self, name)   
         #return self.name
      else:
         raise AttributeError("Con.{0} invalid function.".format(name))
         #return (lambda *args: Con.warn("Con.{0} attribute is not executable.".format(name)))
Con = __Con()

# Console global variable interface class
class __Globals(object):
   def __getattr__(self, name):
      # lookup global variable and return the value            
      result = GetVariable("${0}".format(name))
      if result is None:
         raise AttributeError("Globals.{0} invalid variable attribute.".format(name))
         return
      return result
   def __setattr__(self, name, value):
      # lookup global variable and set the value 
      SetVariable(name, str(value))
      return
Globals = __Globals()

# SimObject interface classes
class _SimObjectAttribute(object):
   def __init__(self, objRef, name):
      # store int or name of simobject
      object.__setattr__(self, "simobject",objRef)
      # store the name of the attribute this object represents
      object.__setattr__(self, "name",name)
   # in case this is returned then do attribute error
   def __str__(self):
      raise AttributeError("SimObject:{0}.{1} invalid attribute.".format(self.simobject,self.name))             
      return ""
   # array access on object
   def __getitem__(self, key):
      sobj = getSimObject(self.simobject)      
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      return SimObjectGetAttribute(sobj, self.name, str(key))
      
   def __setitem__(self, key, value):
      sobj = getSimObject(self.simobject)      
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      SimObjectSetAttribute(sobj, self.name, str(value), str(key))
      return
   
class SimObject(object):   
   def __init__(self, objRef):
      # store int or name of simobject
      object.__setattr__(self, "simobject",objRef)   
   # do not redefine __str__ or __repr__!  it messes all sorts of stuff up      
   def __getattr__(self, name):
      # lookup function and return callable object
      # this will only happen once, after that the name is an attribute on the object
      #print "SimObject::Assigning attribute:",name
      name = str(name).lower()   # save space in lookup dictionary
      sobj = getSimObject(self.simobject)
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      if SimObjectIsMethod(sobj, name):
         #fcObject = FunctionCaller(getSimObject(self.simobject), name)
         #object.__setattr__(self, name, lambda *args: fcObject.ObjectCall(len(args) or 0, map(str,args)))         
         func = makeFunctionCallerLambda(name, self.simobject)         
         object.__setattr__(self, name, func)         
         return getattr(self,name)         
      else:
         if SimObjectIsAttribute(sobj, name):
            #print "Object Field Type:",self.simobject,name,str(SimObjectGetDataFieldType(sobj, name))
            return SimObjectGetAttribute(sobj, name)
         return _SimObjectAttribute(self.simobject, name)
         #raise AttributeError("SimObject:{0}.{1} invalid attribute.".format(self.simobject,name))       
         #return
         #(lambda *args: Con.warn("SimObject:{0}.{1} attribute is not executable.".format(self.simobject,name)))

   def __setattr__(self, name, value):
      sobj = getSimObject(self.simobject)      
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      if SimObjectIsMethod(sobj, name):
         raise AttributeError("SimObject:{0}.{1} is a function not a writeable attribute.".format(self.simobject, name))
         return
      SimObjectSetAttribute(sobj, name, value)   
      
# SimObjects interface class
class __SimObjects(object):
   def __getattr__(self, name):
      objRef = getSimObject(name)
      if objRef is None:
         raise AttributeError('SimObjects: name is not a SimObject: {0}'.format(name))         
      return SimObject(name)   
   def __getitem__(self, index):
      objRef = getSimObject(index)
      if objRef is None:
         raise KeyError('SimObjects: index is not a SimObject: {0:d}'.format(index))
      return SimObject(index)   
SimObjects = __SimObjects()
%}
