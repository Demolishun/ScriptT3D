/*
//-----------------------------------------------------------------------------
// pyT3Dcallbacks.i
//-----------------------------------------------------------------------------

Copyright (c) 2012 Frank Carney

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:
The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
This is a contributing file and not meant to be parsed by SWIG directly.
This file is included in "scriptT3D.i".  Run SWIG against "scriptT3D.i" instead.
*/

%{
   // function def
   static const char * pyScriptCallback(SimObject *obj, Namespace *nsObj, S32 argc, const char **argv);
%}

// callbacks
%{
// util function 
#define PyPRINTOBJ(obj) PyString_AsString(PyObject_Repr(obj))

static const char* SimObjectCallbackAttribName = StringTable->insert("__SimObject__");

// handy defines
#define IS_PYTHON_INTEGER_SEQUENCE(attr) (PyTuple_Check(attr) || PyList_Check(attr))
#define IS_PYTHON_NUMBER(attr) (PyInt_Check(attr) || PyLong_Check(attr) || PyFloat_Check(attr))

// 
// overriden python version of extCallBackObject
//
class pyExtCallBackObject : public extCallBackObject
{
public:
   pyExtCallBackObject(void *object);
   ~pyExtCallBackObject();
   
// functions to be overriden by new class
   // lookup functions
   bool hasMethod(const char *name);
   // export
   //void exportFunctions(extScriptObject *extsobject);

   // attribute functions
   bool hasAttribute(const char *name){return false;};
   const char* getAttribute(const char *name);
   const char* getAttribute(const char *name, const char *index);
   void setAttribute(const char *name, const char *value);
   void setAttribute(const char *name, const char *index, const char *value);
};
// pyExtCallBackObject methods
pyExtCallBackObject::pyExtCallBackObject(void *object)
: extCallBackObject(object)
{
   // nothing in the constructor yet
}
pyExtCallBackObject::~pyExtCallBackObject()
{
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   Py_XDECREF((PyObject *)cbObject);
   
   // protect the GIL
   PyGILState_Release(gstate);
}
// lookup
bool pyExtCallBackObject::hasMethod(const char *name)
{
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   // check if the method exist
   // first check to see if an attribute by that name exists
   PyObject *tmpobj = PyObject_GetAttrString((PyObject*)cbObject, name);
   if(tmpobj){
      if(PyCallable_Check(tmpobj)){
         return true;
      }
   }
   
   // protect the GIL
   PyGILState_Release(gstate);
   
   return false;
}
// export
/*
void pyExtCallBackObject::exportFunctions(extScriptObject *extsobject)
{
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   // buffer of dSprintf
   char buffer[512];
   
   // create unique namespace for object
   //dSprintf(buffer,512,"py%d",extsobject->getId());
   //extsobject->assignName(buffer);
   //extsobject->setInternalName(buffer);
   Namespace *ns = extsobject->getNamespace();
   
   // get list of attributes
   PyObject *tmpList = PyObject_Dir((PyObject *)cbObject);
   if (PyList_Check(tmpList)){
      int size = PyList_Size(tmpList);
      for (int i = 0; i < size; i++) {
         PyObject *ostr = PyList_GetItem(tmpList,i);
         if (PyString_Check(ostr)){
             PyObject *o = PyObject_GetAttr((PyObject *)cbObject, ostr);
             if(PyCallable_Check(o)){
               //Con::printf("%s.%s()",extsobject->getName(),PyString_AsString(ostr));
               //Con::printf("%s.%s()",extsobject->getName(),PyString_AsString(ostr));
               //Con::addScriptCommand(ns, name, pyScriptCallback, usage,  minargs+2, maxargs+2);
               
               dSprintf(buffer,512,"%s()",PyString_AsString(ostr)); // get function name for usage
               ns->addScriptCommand( StringTable->insert(PyString_AsString(ostr)), pyScriptCallback, buffer, 0, 0, false, NULL );
               pyExtCallBackObject *newcbobj = new pyExtCallBackObject((void *)o);
               if(!newcbobj){
                  Con::errorf("pyExtCallBackObject::exportFunctions - error creating pyExtCallBackObject");
                  break;
               }
               struct MarshalNativeEntry *nEntry = script_get_namespace_entry(ns->getName(), PyString_AsString(ostr));
               gScriptCallbackLookup.insertEqual(nEntry->entry,(void*)(newcbobj));
               
               // remember ref
               Py_XINCREF(o);
            }
            else{
               //Con::printf("%s.%s",extsobject->getName(),PyString_AsString(ostr));
            }
         }
      }
   }else{
      Con::errorf("pyExtCallBackObject::exportFunctions : non list object returned");
   }

   // create unique namespace for object
   dSprintf(buffer,512,"py%d",extsobject->getId());
   extsobject->assignName(buffer);
   
   // protect the GIL
   PyGILState_Release(gstate);
}
*/
// python specific attribute manipulation
const char* pyExtCallBackObject::getAttribute(const char *name){
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   const char* ret = NULL;
   
   // get the attribute string
   PyObject *obj = (PyObject *)cbObject;
   PyObject *attr = PyObject_GetAttrString(obj, name);
   if(attr){
      PyObject *str = PyObject_Str(attr);
      if(str)
         ret = PyString_AsString(str);
   }
   else{
      //Con::errorf("pyExtCallBackObject::getAttribute: no attribute %s", name);
   }
   
   // protect the GIL
   PyGILState_Release(gstate);

   return ret;
}
const char* pyExtCallBackObject::getAttribute(const char *name, const char *index){	
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   const char* ret = NULL;
   
   // is index an integer
   S32 indexInt = -1;
   bool isInteger = (dSscanf(index, "%d", &indexInt));
   bool outRange = false;
     
   PyObject *obj = (PyObject *)cbObject;
   PyObject *attr = PyObject_GetAttrString(obj, name);
   if(!attr){
      //Con::errorf("pyExtCallBackObject::getAttribute: no attribute %s", name);
   }
   // determine if attribute is a integer sequence
   else if(IS_PYTHON_INTEGER_SEQUENCE(attr) && !isInteger){
      Con::errorf("pyExtCallBackObject::getAttribute: non-integer index for integer based sequence");
   }
   else if(PyTuple_Check(attr)){
      U32 size = PyTuple_Size(attr);
      if(indexInt >= 0 && indexInt < size){
         PyObject *str = PyObject_Str(PyTuple_GetItem(attr,indexInt));
         if(str)
            ret = PyString_AsString(str);
      }
      else{
         outRange = true;
      }
   }
   else if(PyList_Check(attr)){
      U32 size = PyList_Size(attr);
      if(indexInt >= 0 && indexInt < size){
         PyObject *str = PyObject_Str(PyList_GetItem(attr,indexInt));
         if(str)
            ret = PyString_AsString(str);
      }
      else{
         outRange = true;
      }
   }
   else if(PyDict_Check(attr)){
      // only support string indexes
      PyObject *obj = PyDict_GetItemString(attr,index);
      if(obj){
         PyObject *str = PyObject_Str(obj); // no exception thrown for this get method
         if(str){
            ret = PyString_AsString(str);
         }
      }
      //PyObject *str = PyString_FromString(index);
      //if(PyDict_Contains(attr,str)){
   }
   
   // errors
   if(outRange)
      Con::errorf("pyExtCallBackObject::getAttribute: index out of range");
   
   // protect the GIL
   PyGILState_Release(gstate);
   
   return ret;
}
void pyExtCallBackObject::setAttribute(const char *name, const char *value){
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   // set the attribute string if possible
   PyObject *obj = (PyObject *)cbObject;
   PyObject *attr = PyObject_GetAttrString(obj, name);
   if(!attr){
      //Con::errorf("pyExtCallBackObject::setAttribute: no attribute %s", name);
      PyObject *str = PyString_FromString(value);
      PyObject_SetAttrString(obj,name,str);
   }
   // if a string then just set it
   else if(PyString_Check(attr)){
      PyObject *str = PyString_FromString(value);
      // replace existing attribute
      PyObject_SetAttrString(obj,name,str);
   }
   // if a number then try to set the object as a number
   else if(IS_PYTHON_NUMBER(attr)){
      //S32 indexInt = -1;
      //bool isInteger = (dSscanf(index, "%d", &indexInt));
      PyObject *num = NULL;
      if(PyFloat_Check(attr)){
         F32 number;
         if(dSscanf(value, "%f", &number)){
            num = PyFloat_FromDouble(number);
         }
      }
      else if(PyLong_Check(attr)||PyInt_Check(attr)){
         S32 number;
         if(dSscanf(value, "%d", &number)){
            num = PyLong_FromLong(number);
         }
      }
      if(num){
         PyObject_SetAttrString(obj,name,num);
      }
   }
   
   // protect the GIL
   PyGILState_Release(gstate);
}
void pyExtCallBackObject::setAttribute(const char *name, const char *index, const char *value){
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();
   
   // set the attribute string if possible
   PyObject *obj = (PyObject *)cbObject;
   PyObject *attr = PyObject_GetAttrString(obj, name);
   if(!attr){
      //Con::errorf("pyExtCallBackObject::setAttribute()[]: no attribute %s", name);
      // Create a dictionary on the fly
      PyObject *dict = PyDict_New();
      if(dict){
         PyObject *str = PyString_FromString(value);
         if(str)
            PyDict_SetItemString(dict, index, str);
      }
      PyObject_SetAttrString(obj,name,dict);
   }else if(PyDict_Check(attr)){
      PyObject *str = PyString_FromString(value);
      if(str)
         PyDict_SetItemString(attr, index, str);
   }else if(PyList_Check(attr)){
      S32 number;
      PyObject *str = PyString_FromString(value);
      if(str)
         if(dSscanf(index, "%d", &number)){
            PyList_SetItem(attr,number,str);
         }	
   }
   
   
   // protect the GIL
   PyGILState_Release(gstate);
}

// torque callback, handles console call
//static const char * pyScriptCallback(SimObject *obj, S32 argc, const char **argv){
static const char * pyScriptCallback(SimObject *obj, Namespace *nsObj, S32 argc, const char **argv){
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();

   PyObject *pyobj=NULL, *tmpfunc, *tuple;
   //extScriptCBObject *tmpSBObject;
   pyExtCallBackObject *tmpSBObject;
   Namespace::Entry *nsEntry = NULL;
   
   // buffer for temp strings
   //char tempStr[512];
   const char *retstr = "";
   
   // add attribute name to StringTable
   //StringTableEntry attrname = StringTable->insert("__SimObject__"); 
   StringTableEntry attrname = SimObjectCallbackAttribName;
   
   // external namespace?
   //bool extNS = false;
   
   //Con::printf("number of arguments: %d",argc);
   //Con::printf("pyScriptCallback: %s::%s", CurrentNSEntry->mNamespace->mName, CurrentNSEntry->mFunctionName);
   
   //bool tsMethod = false;
   
   if(obj){
      //Con::printf("Function called against object: %s::%s",obj->getName(), argv[0]);
      //nEntry = script_get_namespace_entry(obj->getName(), argv[0]); 
      Namespace *ns = obj->getNamespace();
      nsEntry = ns->lookupRecursive(argv[0]);
      // this is a TS method and must return SimObject ID to callback
      //tsMethod = true;
      //Con::printf("%s::%s in lookup.", argv[1], argv[0]);
      if(!nsEntry)
         Con::printf("Could not find %s::%s in lookup.", obj->getName(), argv[0]);
   }
   if(!nsEntry && nsObj->mName != NULL){
      //Con::printf("pyScriptCallback: %s::%s", nsObj->Entry->mNamespace->mName, argv[0]);
      nsEntry = script_get_namespace_entry(nsObj->mName, argv[0])->entry;
   }
   if(!nsEntry){
      //Con::printf("Function called in global namespace: %s", argv[0]);
      nsEntry = script_get_namespace_entry(NULL, argv[0])->entry;
      if(!nsEntry)
         Con::printf("Could not find %s in lookup.", argv[0]);
   }
   if(!nsEntry){
      //Con::errorf("pyScriptCallback cannot determine namespace for this function and cannot find it in global namespace.");
      PyGILState_Release(gstate);
      return "";
   }
   
   if(!gScriptCallbackLookup.find(nsEntry, (void *&)(tmpSBObject))){
      Con::errorf("pyScriptCallback found the function but cannot find the corresponding Python callback.");
      PyGILState_Release(gstate);
      return "";
   }
   if(!tmpSBObject){
      Con::errorf("pyScriptCallback a null script object was returned from lookup.");
      PyGILState_Release(gstate);
      return "";
   }
   //if(tmpSBObject->getType() != extScriptCBObject::PythonCallback){
   //	Con::errorf("pyScriptCallback attempt to call non extScriptCBObject::PythonCallback on object.");
   //	PyGILState_Release(gstate);
   //	return "";
   //}

   // get type of object print to console
   /*
   PyObject *tmpType = PyObject_Type((PyObject *)tmpSBObject->getObject());  
   char * tmpTypeString = PyString_AsString(PyObject_Str(tmpType));
   PyErr_Clear();
   Con::warnf("Checking type of function.");
   if(tmpTypeString){      
      Con::warnf("Printing type string of function object: %s",tmpTypeString);
   }else{
      Con::errorf("Could not print type string of function object.");
   }
   */
   
   // create parameter list
   if(obj)
      tuple = PyTuple_New(argc-2);
   else
      tuple = PyTuple_New(argc-1);
   if(!tuple){
      Con::errorf("pyScriptCallback error allocating memory while creating PyTuple.");
      PyGILState_Release(gstate);
      return "";
   }
   int tupleIndex=0;
   // sneaky way to tell the Python function what SimObject called this function
   // if there is a simobject then pass as attribute to function
   if(obj){
      // convert simobject to python object
      // api is different when builtin is enabled
      // SWIG_InternalNewPointerObj is identical to SWIG_NewPointerObj when builtin is off 
      //pyobj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), SWIGTYPE_p_SimObject, 0 |  0 );
      pyobj = SWIG_InternalNewPointerObj(SWIG_as_voidptr(obj), SWIGTYPE_p_SimObject, 0 );      

      if(pyobj){   
         if(PyMethod_Check((PyObject *)tmpSBObject->getObject())){
            PyObject_SetAttrString(PyMethod_Function((PyObject *)tmpSBObject->getObject()),attrname,pyobj);
         }else{
            PyObject_SetAttrString((PyObject *)tmpSBObject->getObject(),attrname,pyobj);	
         }
      }
   }
   // populate arguments
   int count;
   // if object is present so is namespace
   if(obj)
      count=2;
   else
      count=1;
   for(; count<argc; count++){
      PyObject *tref = PyString_FromString(argv[count]);
      //Con::printf("pyScriptCallback arg: %s",argv[count]);
      if(!tref){
         Con::errorf("pyScriptCallback error allocating memory while creating PyTuple entry.");
         Py_DECREF(tuple);				
         PyGILState_Release(gstate);
         return "";
      }
      PyTuple_SetItem(tuple, tupleIndex++, tref);
   }
   
   // call function
   PyObject *result = NULL;
   //tmpfunc = (PyObject *)tmpSBObject->getFunction();
   tmpfunc = (PyObject *)tmpSBObject->getObject();
   result = PyEval_CallObject(tmpfunc, tuple);
   Py_DECREF(tuple);
   if (result == NULL){
      //pvalue contains error message
      //ptraceback contains stack snapshot and many other information
      //(see python traceback structure)
      PyObject *ptype, *pvalue, *ptraceback;
      PyErr_Fetch(&ptype, &pvalue, &ptraceback);

      //Get error message
      char *pStrErrorMessage = PyString_AsString(pvalue);
      Con::errorf("pyScriptCallback: %s",pStrErrorMessage);
      PyErr_Clear();
   }else{
      // get results
      //const char *tmpstr = NULL;
      if(result != Py_None){
         PyObject *resconv = PyObject_Str(result);
         retstr = Con::getReturnBuffer(PyString_AsString(resconv));
      }
   }
   // remove __SimObject__ from function object
   if(obj && pyobj){
      if(PyMethod_Check((PyObject *)tmpSBObject->getObject())){         
         if(PyObject_HasAttrString(PyMethod_Function((PyObject *)tmpSBObject->getObject()),attrname)){
            PyObject_DelAttrString(PyMethod_Function((PyObject *)tmpSBObject->getObject()),attrname);
         }
      }else{
         if(PyObject_HasAttrString((PyObject *)tmpSBObject->getObject(),attrname)){
            PyObject_DelAttrString((PyObject *)tmpSBObject->getObject(),attrname);
         }
      }      
   }
   
   // release refs
   Py_XDECREF(result);
   
   // protect the GIL
   PyGILState_Release(gstate);
   
   return retstr;
}

// exporting Python functions to Torque Script
static PyObject * ExportCallback(PyObject *self, PyObject *pyargs){
//static PyObject * ExportCallback(PyObject *self, PyObject *pyargs, PyObject *keywds){
   PyObject *result;
   PyObject *pyfunc;
   const char *name;
   const char *usage = ""; // empty default
   //U32 minargs, maxargs;
   const char *ns = NULL;
   bool overrides = true;
   
   // buffer for temp strings
   char tempStr[512];

   // argument kwlist
   //static char *kwlist[] = {"function", "name", "usage", "ns", "override", NULL};

   // parse args and bail if args are wrong
   //if (!PyArg_ParseTuple(pyargs, "OssII|zb", &pyfunc, &name, &usage, &minargs, &maxargs, &ns, &override))
   // %native method does not support kwargs in a simple way
   //if (!PyArg_ParseTupleAndKeywords(pyargs, keywds, "Os|szb", kwlist, &pyfunc, &name, &usage, &ns, &overrides))
   // Note: ns (namespace) is now before usage.
   if (!PyArg_ParseTuple(pyargs, "Os|zzb", &pyfunc, &name, &ns, &usage, &overrides)) {
        return NULL;
   }
        
    // check for empty namespace strings
    if(ns && !dStrlen(ns))
      ns = NULL;

   // check first arg is python function or bail if not
   if (!PyCallable_Check(pyfunc)){
      dSprintf(tempStr, 512, "First arg must be a valid function. %s does not appear to be a function.",PyPRINTOBJ(pyfunc));
        PyErr_SetString(PyExc_TypeError, tempStr);
        return NULL;
    }
    
    // check for proper console namespace and function names
    if(ns)
      if(!isValidIdentifier(ns)){
         dSprintf(tempStr, 512, "Invalid function namespace identifier: %s",ns);
         PyErr_SetString(PyExc_ValueError, tempStr);
         return NULL;
      }
   if(!isValidIdentifier(name)){
      dSprintf(tempStr, 512, "Invalid function name identifier: %s",name);
      PyErr_SetString(PyExc_ValueError, tempStr);
      return NULL;
   }
   
   // determine if console function exists already if it does bail with exception
   // GetEntry will return non NULL if a function exists either in ns::name() or name() forms
   struct MarshalNativeEntry *nEntry = NULL;
   if(!overrides)
      nEntry = script_get_namespace_entry(ns, name);
      if(nEntry) {
         dSprintf(tempStr, 512, "%s::%s function was previously exported or was defined in Torque script",nEntry->nameSpace,nEntry->name);
         PyErr_SetString(PyExc_ValueError, tempStr);
         return NULL;
      }
         
   // register function	
   if (!ns)  //(!ns || !dStrlen(ns))
   {
      Con::printf("exporting function: %s", name);
      //script_export_callback_string(pyScriptCallback, ns, name, usage,  minargs, maxargs);
      //Con::addScriptCommand(ns, name, pyScriptCallback, usage,  minargs+1, maxargs+1);
      Con::addScriptCommand(ns, name, pyScriptCallback, usage,  0, 0);
   }
   else{
      Con::printf("exporting function: %s::%s", ns, name);
      // must provide an object as first parameter so increase args by 1
      //script_export_callback_string(pyScriptCallback, ns, name, usage,  minargs+1, maxargs+1);
      //Con::addScriptCommand(ns, name, pyScriptCallback, usage,  minargs+2, maxargs+2);
      Con::addScriptCommand(ns, name, pyScriptCallback, usage,  0, 0);
   }
      
   // add to callback lookup table
   nEntry = script_get_namespace_entry(ns, name);	
   //extScriptCBObject *tempcbobj = NULL;
   pyExtCallBackObject *tempcbobj = NULL;
   if(gScriptCallbackLookup.find(nEntry->entry, (void *&)(tempcbobj))){
      //Con::printf("found previous entry");		
   }
   //extScriptCBObject *newcbobj = new extScriptCBObject(extScriptCBObject::PythonCallback, (void *)pyfunc, 0, NULL, pyScriptCBObjectFunction);
   pyExtCallBackObject *newcbobj = new pyExtCallBackObject((void *)pyfunc);
   if(!newcbobj){
      dSprintf(tempStr, 512, "%s::%s function registraction failed to allocate memory for extScriptCBObject.",nEntry->nameSpace,nEntry->name);
      PyErr_SetString(PyExc_MemoryError, tempStr);
      return NULL;
   }	
   gScriptCallbackLookup.insertEqual(nEntry->entry,(void*)(newcbobj));
   // if we got an old callback object delete it, cleanup function will do work of cleaning up objects
   if(tempcbobj)
      delete tempcbobj;
   
   // increment ref count for python function object
   Py_XINCREF(pyfunc);
   
   /* Boilerplate to return "None" */
    Py_INCREF(Py_None);
    result = Py_None;
    return result;
}

//
// This implementation of a consumer assumes 1 Python consumer.
//

// console consumer variables
PyObject *pyConsumerCallback = NULL;

// console consumer functions
void conConsumerCallback(U32 level, const char *consoleLine){
   // protect the GIL
   PyGILState_STATE gstate;
   gstate = PyGILState_Ensure();

   // check for registered python function
   if(pyConsumerCallback){
      PyObject *tuple = PyTuple_New(2);
      PyObject *plevel = PyLong_FromLong(level);
      PyObject *pline = PyString_FromString(consoleLine);
      if(!tuple || !plevel || !pline){
         Con::errorf("conConsumerCallback: error allocating memory while creating PyTuple entries.");
         // protect the GIL
         PyGILState_Release(gstate);
         return;
      }
      int tupleIndex=0;
      // assign arguments to tuple
      PyTuple_SetItem(tuple, tupleIndex++, plevel);
      PyTuple_SetItem(tuple, tupleIndex++, pline);

      // now call callback
      PyObject *result = PyEval_CallObject(pyConsumerCallback, tuple);
      Py_DECREF(tuple);
      if (result == NULL){
         //pvalue contains error message
         //ptraceback contains stack snapshot and many other information
         //(see python traceback structure)
         PyObject *ptype, *pvalue, *ptraceback;
         PyErr_Fetch(&ptype, &pvalue, &ptraceback);

         //Get error message
         char *pStrErrorMessage = PyString_AsString(pvalue);
         Con::errorf("conConsumerCallback: %s",pStrErrorMessage);
         PyErr_Clear();
      }
   } // if no consumer callback silently fail

   // protect the GIL
   PyGILState_Release(gstate);
}

// assign python function as consumer
// if Py_None is passed as object then disable consumer
static PyObject * ExportConsumer(PyObject *self, PyObject *pyargs){
   PyObject *result;
   PyObject *pyfunc;

   // buffer for temp strings
   char tempStr[512];

   // check parameters
   if (!PyArg_ParseTuple(pyargs, "O", &pyfunc))
        return NULL;

   // check of Py_None
   if(pyfunc == Py_None){
      // remove consumer
      Py_XDECREF(pyConsumerCallback);
      pyConsumerCallback = NULL;
      Con::removeConsumer(conConsumerCallback);
   }else{
      // check first arg is python function or bail if not
      if (!PyCallable_Check(pyfunc)){
         dSprintf(tempStr, 512, "First and only arg must be a valid function. %s does not appear to be a function.",PyPRINTOBJ(pyfunc));
         PyErr_SetString(PyExc_TypeError, tempStr);
         return NULL;
      }

      // set callback
      Py_XDECREF(pyConsumerCallback); // squash any previous refs
      pyConsumerCallback = pyfunc;
      Py_INCREF(pyfunc);
      Con::addConsumer(conConsumerCallback);
   }

   /* Boilerplate to return "None" */
   Py_INCREF(Py_None);
   result = Py_None;
   return result;
}
%}

%native(ExportCallback) static PyObject * ExportCallback(PyObject *self, PyObject *pyargs);
%native(ExportConsumer) static PyObject * ExportConsumer(PyObject *self, PyObject *pyargs);

