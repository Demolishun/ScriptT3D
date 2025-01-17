# This file was automatically generated by SWIG (http://www.swig.org).
# Version 2.0.8
#
# Do not make changes to this file unless you know what you are doing--modify
# the SWIG interface file instead.



from sys import version_info
if version_info >= (2,6,0):
    def swig_import_helper():
        from os.path import dirname
        import imp
        fp = None
        try:
            fp, pathname, description = imp.find_module('_scriptT3D', [dirname(__file__)])
        except ImportError:
            import _scriptT3D
            return _scriptT3D
        if fp is not None:
            try:
                _mod = imp.load_module('_scriptT3D', fp, pathname, description)
            finally:
                fp.close()
            return _mod
    _scriptT3D = swig_import_helper()
    del swig_import_helper
else:
    import _scriptT3D
del version_info
from _scriptT3D import *
try:
    _swig_property = property
except NameError:
    pass # Python < 2.2 doesn't have 'property'.
def _swig_setattr_nondynamic(self,class_type,name,value,static=1):
    if (name == "thisown"): return self.this.own(value)
    if (name == "this"):
        if type(value).__name__ == 'SwigPyObject':
            self.__dict__[name] = value
            return
    method = class_type.__swig_setmethods__.get(name,None)
    if method: return method(self,value)
    if (not static):
        self.__dict__[name] = value
    else:
        raise AttributeError("You cannot add attributes to %s" % self)

def _swig_setattr(self,class_type,name,value):
    return _swig_setattr_nondynamic(self,class_type,name,value,0)

def _swig_getattr(self,class_type,name):
    if (name == "thisown"): return self.this.own()
    method = class_type.__swig_getmethods__.get(name,None)
    if method: return method(self)
    raise AttributeError(name)

def _swig_repr(self):
    try: strthis = "proxy of " + self.this.__repr__()
    except: strthis = ""
    return "<%s.%s; %s >" % (self.__class__.__module__, self.__class__.__name__, strthis,)

try:
    _object = object
    _newclass = 1
except AttributeError:
    class _object : pass
    _newclass = 0


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
   # Hack to force this attribute to be name "Exec".  Python does not like objects to have an attribute named "exec".
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
      result = getVariable("${0}".format(name))
      if result is None:
         raise AttributeError("Globals.{0} invalid variable attribute.".format(name))
         return
      return result
   def __setattr__(self, name, value):
      # lookup global variable and set the value 
      setVariable(name, str(value))
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
      return getSimObjectAttribute(sobj, self.name, str(key))
      
   def __setitem__(self, key, value):
      sobj = getSimObject(self.simobject)      
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      setSimObjectAttribute(sobj, self.name, str(value), str(key))
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
      if isSimObjectMethod(sobj, name):
         #fcObject = FunctionCaller(getSimObject(self.simobject), name)
         #object.__setattr__(self, name, lambda *args: fcObject.ObjectCall(len(args) or 0, map(str,args)))         
         func = makeFunctionCallerLambda(name, self.simobject)         
         object.__setattr__(self, name, func)         
         return getattr(self,name)         
      else:
         if isSimObjectAttribute(sobj, name):
            #print "Object Field Type:",self.simobject,name,str(SimObjectGetDataFieldType(sobj, name))
            return getSimObjectAttribute(sobj, name)
         return _SimObjectAttribute(self.simobject, name)
         #raise AttributeError("SimObject:{0}.{1} invalid attribute.".format(self.simobject,name))       
         #return
         #(lambda *args: Con.warn("SimObject:{0}.{1} attribute is not executable.".format(self.simobject,name)))

   def __setattr__(self, name, value):
      sobj = getSimObject(self.simobject)      
      if sobj == None:
         raise RuntimeError("SimObject:{0} object does not exist.".format(self.simobject))
         return
      if isSimObjectMethod(sobj, name):
         raise AttributeError("SimObject:{0}.{1} is a function not a writeable attribute.".format(self.simobject, name))
         return
      setSimObjectAttribute(sobj, name, str(value))   
      
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
         raise KeyError('SimObjects: index is not a SimObject: {0}'.format(str(index)))
      return SimObject(index)   
SimObjects = __SimObjects()


# This file is compatible with both classic and new-style classes.


