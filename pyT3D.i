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
swig_RestrictedAttributes = ["this","thisown"]
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

%{
	// function def
	static const char * pyScriptCallback(SimObject *obj, Namespace *nsObj, S32 argc, const char **argv);
%}

// callbacks
%{
// util function 
#define PyPRINTOBJ(obj) PyString_AsString(PyObject_Repr(obj))

static const char* SimObjectCallbackAttribName = StringTable->insert("__SimObject__");;

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
	void exportFunctions(extScriptObject *extsobject);

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
void pyExtCallBackObject::exportFunctions(extScriptObject *extsobject)
{
	// protect the GIL
	PyGILState_STATE gstate;
	gstate = PyGILState_Ensure();
	
	// buffer of dSprintf
	char buffer[512];
	
	// create unique namespace for object
	dSprintf(buffer,512,"py%d",extsobject->getId());
	extsobject->assignName(buffer);
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
	
	// protect the GIL
	PyGILState_Release(gstate);
}

// handy defines
#define IS_PYTHON_INTEGER_SEQUENCE(attr) (PyTuple_Check(attr) || PyList_Check(attr))
#define IS_PYTHON_NUMBER(attr) (PyInt_Check(attr) || PyLong_Check(attr) || PyFloat_Check(attr))

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
		pyobj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), SWIGTYPE_p_SimObject, 0 |  0 );
		
		if(pyobj){
			PyObject_SetAttrString((PyObject *)tmpSBObject->getObject(),attrname,pyobj);	
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
	// remove SimObject_this from function object
	if(obj && pyobj){
		if(PyObject_HasAttrString((PyObject *)tmpSBObject->getObject(),attrname)){
			PyObject_DelAttrString((PyObject *)tmpSBObject->getObject(),attrname);
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
		if(nEntry = script_get_namespace_entry(ns, name)) {
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

// exporting Python objects to Torque Script
/* 
	A Python decorator or function will be used to handle objects 
	that are callable by optionally adding the object as a function.
	The reason it is not done here is for simplicity and keeping it
	from being an automatic feature that might dirty the namespace if
	the extScriptObject objects are deleted.
*/
static PyObject * ExportObject(PyObject *self, PyObject *pyargs){
	PyObject *result;
	PyObject *pyobj;
	const char *name = NULL;
	const char *properties = NULL;
	//const char *usage = NULL;
	//U32 minargs = 0, maxargs = 63; // arbitrary defaults
	//const char *ns = NULL;
	//bool override = false;
	
	// buffer for temp strings
	char tempStr[512];

	// parse args and bail if args are wrong
	// only object is required, the rest are optional
	//if (!PyArg_ParseTuple(pyargs, "O|ssIIb", &pyobj, &name, &usage, &minargs, &maxargs, &override))
	if (!PyArg_ParseTuple(pyargs, "O|ss", &pyobj, &name, &properties))
        return NULL;
        
    // create the object
    // SimObject *spawnObject(String spawnClass, String spawnDataBlock, String spawnName,
    //                        String spawnProperties, String spawnScript)
    //if(!name || !dStrlen(name))
    extScriptObject *tmpsobj = (extScriptObject*)Sim::spawnObject(String("extScriptObject"),String(""),String(name),String(properties));
    if(tmpsobj){
		// create the object to handle Python object ref
		pyExtCallBackObject *newcbobj = new pyExtCallBackObject((void *)pyobj);
		tmpsobj->SetObject(newcbobj);
    }
    else{
		dSprintf(tempStr, 512, "ExportObject failed to create a extScriptObject. NULL was returned. %s",PyPRINTOBJ(pyobj));
        PyErr_SetString(PyExc_MemoryError, tempStr);
        return NULL;
    }
	
	// increment ref count for python object
	Py_XINCREF(pyobj);
    
    // ret object ref
    if(tmpsobj){
		// convert simobject to python object
		PyObject *pyso = SWIG_NewPointerObj(SWIG_as_voidptr(tmpsobj), SWIGTYPE_p_SimObject, 0 |  0 );
		Py_INCREF(pyso);

		result = pyso;
	}else{
		/* Boilerplate to return "None" */
		Py_INCREF(Py_None);
		result = Py_None;
	}
    
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
//static PyObject * ExportCallback(PyObject *self, PyObject *pyargs, PyObject *kwargs);
%native(ExportObject) static PyObject * ExportObject(PyObject *self, PyObject *pyargs);
%native(ExportConsumer) static PyObject * ExportConsumer(PyObject *self, PyObject *pyargs);

%pythoncode %{
def BuildExecString(objName,splitval,name,*args):
	targs = ""
	amax = len(args)
	for i in range(amax):
		arg = args[i]
		targs += '"'+str(arg)+'"'
		if(i < amax-1):
			targs += ","
	if objName is not None:
		fcall = "return "+objName+splitval+name+"("+targs+");"
	else:
		fcall = "return "+name+"("+targs+");"
		
	return fcall
	
# stores object and attribute used to retrieve data in this string object
# object and attribute is used in array semantics to further get more data
class AttributeObject(str):	
	def __new__(cls, value, data):
		nobj = str.__new__(cls, value)
		nobj.data = data
		return nobj
	
	# array semantics
	def __setitem__(self, key, value):
		self.data[0].SetAttribute(self.data[1],str(value),str(key))	
	def __getitem__(self, key):
		val = self.data[0].GetAttribute(self.data[1],str(key))
		return val
%}

class SimObject {
public:	
	%pythoncode %{
	def __str__(self):
		return self.getID()
	def __repr__(self):
		# this returns a string of an object script in TS
		return self.GetScript()
		
	# redefine for accessing attributes and methods
	# save original function
	__setattr_org__ = __setattr__
	def __setattr__(self, attribute, value):
		if attribute in swig_RestrictedAttributes:
			self.__setattr_org__(attribute, value)
			return
			
		#print attribute
		# explicit conversion
		value = str(value)
					
		self.SetAttribute(attribute, value)
		if self.GetAttribute(attribute) != value:
			raise AttributeError(attribute, "Failed to set attribute to: "+value)
		
	# save original function
	__getattr_org__ = __getattr__
	def __getattr__(self, attribute):
		if attribute in swig_RestrictedAttributes:
			return self.__getattr_org__(attribute)
		
		if self.IsMethod(attribute):
			def tfunc(*args):
				targs = [attribute,""]
				for arg in args:
					targs.append(str(arg))
				ret = self.CallMethod(len(targs),targs)
				return AttributeObject(ret,(self,attribute))
			return tfunc
		else:			
			ret = self.GetAttribute(attribute)
			# there is no way to tell if this failed or succeeded
			#if ret is None:
			#	raise AttributeError(attribute, "Failed to get attribute value.")
			return AttributeObject(ret, (self,attribute))
	%}	
};

%extend SimObject {
	// self = this pointer
	bool IsAttribute(const char* attribname, bool includeStatic = true, bool includeDynamic = true){
		return self->isField(attribname, includeStatic, includeDynamic);
	}
	bool IsMethod(const char* funcname){
		return self->isMethod(funcname);
	}
	// must use StringTable->insert for string to be found by object, otherwise value cannot be returned in console
	//const char *getDataField(StringTableEntry slotName, const char *array);
	const char *GetAttribute(const char *attribName, const char *index=NULL){
		return self->getDataField(StringTable->insert(attribName), index);
	}
	//void setDataField(StringTableEntry slotName, const char *array, const char *value);
	void SetAttribute(const char *attribName, const char *value, const char *index=NULL){
		self->setDataField(StringTable->insert(attribName), index, value);
	}
	// execute methods on this object
	const char* CallMethod(S32 argc, const char** argv){
		return Con::execute(self, argc, argv);
	}
	// write object script to string
	const char* GetScript(){
		return getSimObjectScript(self);
	}
}

%rename("Sim") "SimSpace";
class SimSpace {
public:
	//static SimSpace& getInstance();
	SimObject * FindObject(S32 param);
	SimObject * FindObject(const char *param);
	const char* GetVariable(const char *name);
	bool SetVariable(const char* name, const char* value);
	bool IsFunction(const char *nameSpace, const char *name);
	const char* Evaluate(const char* code);
	const char* Execute(const char* simobj, S32 argc, const char** argv);
	//const char* Execute(S32 argc, const char** argv);
	bool ExecuteFailed();
	
	%pythoncode %{
	# redefine for accessing Sim based objects, variables and functions
	# save original function
	__setattr_org__ = __setattr__
	def __setattr__(self, attribute, value):
		if attribute in swig_RestrictedAttributes:
			self.__setattr_org__(attribute, value)
			return
		try:
			self.__setitem__(attribute, value)
			return
		except KeyError,e:
			raise AttributeError(attribute)
	# save original function
	__getattr_org__ = __getattr__
	def __getattr__(self, attribute):
		if attribute in swig_RestrictedAttributes:
			return self.__getattr_org__(attribute)
		try:
			return self.__getitem__(attribute)
		except KeyError,e:
			raise AttributeError(attribute)
		
	# dictionary style access to Sim based objects, variables and functions
	def __setitem__(self, key, value):		
		setattr = self.SetVariable(key, value)
		if setattr:
			return
			
		raise KeyError(key,"is not a valid console variable.")
	
	def __getitem__(self, key):
		key = str(key)
		
		# find attribute in console if possible
		sobj = self.FindObject(key)
		if sobj is not None:
			return sobj
		svar = self.GetVariable(key)
		if len(svar):
			return svar
		
		splitval = None
		if "::" in key:
			fname = key.split("::")
			splitval = "::"
		elif "." in key:
			fname = key.split(".")
			splitval = "."
		else:
			fname = [key]
		if len(fname) == 1:
			fbool = self.IsFunction(None,fname[0])
			if fbool:
				def tfunc(*args):
					#print "function call:",fname[0]
					#fcall = BuildExecString(None,None,fname[0],*args)
					#ret = self.Evaluate(fcall)
					targs = [fname[0]]
					for arg in args:
						targs.append(str(arg))
					ret = self.Execute(None,len(targs),targs)
					return ret	
				return tfunc
		elif len(fname) == 2:
			fbool = self.IsFunction(fname[0],fname[1])
			if fbool:
				#print "function call:",fname[0]+splitval+fname[1]
				if splitval == "::":
					def tfunc(*args):
						fcall = BuildExecString(fname[0],splitval,fname[1],*args)
						#print "BuildExecString",fcall
						ret = self.Evaluate(fcall)
						return ret
					return tfunc
				else:
					def tfunc(*args):
						targs = [fname[1],""]
						for arg in args:
							targs.append(str(arg))
						ret = self.Execute(fname[0],len(targs),targs)
						if self.ExecuteFailed():
							raise KeyError(key,"not a valid SimObject in function call.")
						return ret
					return tfunc
				
		# if an attribute cannot be found
		raise KeyError(key,"is not a valid console variable.")

	def __str__(self):
		return "Sim interface for console methods."

	%}	
};