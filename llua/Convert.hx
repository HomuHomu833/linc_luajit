package llua;


import llua.State;
import llua.Lua;
import llua.LuaL;
import llua.Macro.*;
import haxe.DynamicAccess;
class Convert {

	/**
	 * To Lua
	 */
	public static var enableUnsupportedTraces = false;
	//TODO: should be cleared maybe before creating a table?
	static var _funcs = [];
	public static function toLua(l:State, val:Any, ?o:Any, ?recursive:Bool = true):Bool {
		// recursive restricts further object conversion so it doesn't lag and possibly further crash (without a error) due to memory overheap 
		switch (Type.typeof(val)) {
			case Type.ValueType.TNull:
				Lua.pushnil(l);

			case Type.ValueType.TBool:
				Lua.pushboolean(l, val);
				
			case Type.ValueType.TInt:
				Lua.pushinteger(l, cast(val, Int));

			case Type.ValueType.TFunction:
				Lua.pushnumber(l, _funcs.push(val) - 1);
				Lua.pushcclosure(l, _anon_callback, 1);

			case Type.ValueType.TFloat:
				Lua.pushnumber(l, val);

			case Type.ValueType.TClass(String):
				Lua.pushstring(l, cast(val, String));

			case Type.ValueType.TClass(Array):
				var arr:Array<Any> = val;
				Lua.createtable(l, arr.length, 0);
				for (i => v in arr) {
					Lua.pushnumber(l, i + 1);
					toLua(l, v, arr, false);
					Lua.settable(l, -3);
				}

			case TClass(_):
				if (val is haxe.Constraints.IMap) {
					var map:haxe.Constraints.IMap<Any, Any> = val;
					Lua.createtable(l, 0, 0);
					for (index => val in map) {
						Lua.pushstring(l, Std.string(index));
						toLua(l, val, map, false);
						Lua.settable(l, -3);
					}
					return true;
				}

				if (!recursive) {
					Lua.pushnil(l);
					return true;
				}

				Lua.createtable(l, 0, 0);
				for (key in Type.getInstanceFields(Type.getClass(val))) {
					Lua.pushstring(l, key);
					toLua(l, Reflect.getProperty(val, key), val, false);
					Lua.settable(l, -3);
				}

			case TObject:
				if (!recursive) {
					Lua.pushnil(l);
					return true;
				}

				Lua.createtable(l, 0, 0);
				var obj:DynamicAccess<Any> = val;
				for (key in obj.keys()) {
					Lua.pushstring(l, key);
					toLua(l, obj.get(key), cast obj, false);
					Lua.settable(l, -3);
				}

			default:
				if(enableUnsupportedTraces) trace('Haxe value of $val of type ${Type.typeof(val)} not supported!' );
				Lua.pushnil(l);
				return false;
		}
		return true;
	}

	#if cpp
	static var _anon_callback = cpp.Callable.fromStaticFunction(anon_function);
	#end

	static function anon_function(l:llua.StatePointer) {
		var l:State = cast cpp.Pointer.fromRaw(l).ref;

		var numArgs = Lua.gettop(l);
		var o = null;
		var f = _funcs[cast Lua.tonumber(l, Lua.upvalueindex(1))];
		var args = [];
		for (i in 0...numArgs)
			args[i] = fromLua(l, i + 1);
		var result = Reflect.callMethod(o, f, args);
		return toLua(l, result) ? 1 : 0;
	}

	// public static function callback_handler(cbf:Dynamic,l:State,?object:Dynamic/*,cbf:Dynamic,lsp:Dynamic*/):Int {
	// 	try{
	// 		final l:State = l;
	// 		final nparams:Int = Lua.gettop(l);

	// 		if(cbf == null) return 0;

	// 		/* return the number of results */
	// 		final ret:Dynamic = Reflect.callMethod(object,cbf,[for (i in 0...nparams) fromLua(l, i + 1)]);
	// 		if(ret != null){
	// 			toLua(l, ret);
	// 			return 1;
	// 		}
	// 	}catch(e){
	// 		trace('${e}');
	// 		throw(e);
	// 	}
	// 	return 0;

	// }
	// @:keep static inline function instanceToLua(l:State, res:Any) {
	// 	Lua.createtable(l, 0, 0);
	// 	Lua.pushstring(l, "__index");

	// 	// for (n in Reflect.fields(res)){
	// 	// 	Lua.pushstring(l, n);
	// 	// 	toLua(l, Reflect.field(res, n));
	// 	// 	Lua.settable(l, -3);
	// 	// }
	// }

	@:keep public static inline function setGlobal(l:State, index:String, value:Dynamic) {
		// Lua.getglobal(l, Lua.LUA_GLOBALSINDEX);
		// toLua(l, index);

		toLua(l, value);
		Lua.setfield(l, Lua.LUA_GLOBALSINDEX, index);
		// Lua.settable(l, -3);
		// Lua.pop(l,0);
	}
	/**
	 * From Lua
	 */
	public static function fromLua(l:State, v:Int):Any {

		final luaType = Lua.type(l, v);
		return switch(luaType) {
			case Lua.LUA_TNIL:
				null;
			case Lua.LUA_TBOOLEAN:
				Lua.toboolean(l, v);
			case Lua.LUA_TNUMBER:
				Lua.tonumber(l, v);
			case Lua.LUA_TSTRING:
				Lua.tostring(l, v);
			case Lua.LUA_TTABLE:
				toHaxeObj(l, v);
			case Lua.LUA_TFUNCTION: // From https://github.com/DragShot/linc_luajit/
				new LuaCallback(l, LuaL.ref(l, Lua.LUA_REGISTRYINDEX));
			// 	trace("function\n");
			// case Lua.LUA_TUSERDATA:
			// 	ret = LuaL.ref(l, Lua.LUA_REGISTRYINDEX);
			// 	trace("userdata\n");
			// case Lua.LUA_TLIGHTUSERDATA:
			// 	ret = LuaL.ref(l, Lua.LUA_REGISTRYINDEX);
			// 	trace("lightuserdata\n");
			// case Lua.LUA_TTHREAD:
			// 	ret = null;
			// 	trace("thread\n");
			default:
				if(enableUnsupportedTraces) trace('Return value $v of type $luaType not supported');
				null;
		}

	}

	/*static inline function fromLuaTable(l:State):Any {

		var array:Bool = true;
		var ret:Any = null;

		Lua.pushnil(l);
		while(Lua.next(l,-2) != 0) {

			if (Lua.type(l, -2) != Lua.LUA_TNUMBER) {
				array = false;
				Lua.pop(l,2);
				break;
			}

			// check this
			var n:Float = Lua.tonumber(l, -2);
			if(n != Std.int(n)){
				array = false;
				Lua.pop(l,2);
				break;
			}

			Lua.pop(l,1);

		}

		if(array){

			var arr:Array<Any> = [];
			Lua.pushnil(l);
			while(Lua.next(l,-2) != 0) {
				var index:Int = Lua.tointeger(l, -2) - 1; // lua has 1 based indices instead of 0
				arr[index] = fromLua(l, -1); // with holes
				Lua.pop(l,1);
			}
			ret = arr;

		} else {

			var obj:Anon = Anon.create(); // {}
			Lua.pushnil(l);
			while(Lua.next(l,-2) != 0) {
				obj.add(Std.string(fromLua(l, -2)), fromLua(l, -1)); // works with mixed tables
				Lua.pop(l,1);
			}
			ret = obj;

		}

		return ret;

	}

}*/
	public static function toHaxeObj(l, i:Int):Any {
		var hasItems = false;
		var array = true;

		loopTable(l, i,{
			hasItems = true;
			if(Lua.type(l, -2) != Lua.LUA_TNUMBER){
				array = false; 
			}
			final index = Lua.tonumber(l, -2);
			if(index < 0 || Std.int(index) != index) {
				array = false; 
			}
		});
		if(!hasItems) return {}

		if(array) {
			final v:Array<Dynamic> = [];
			loopTable(l, i, {
				v[Std.int(Lua.tonumber(l, -2)) - 1] = fromLua(l, -1);
			});
			return cast v;
		}
		final v:DynamicAccess<Any> = {};
		loopTable(l, i, {
			switch Lua.type(l, -2) {
				case t if(t == Lua.LUA_TSTRING): v.set(Lua.tostring(l, -2), fromLua(l, -1));
				case t if(t == Lua.LUA_TNUMBER):v.set(Std.string(Lua.tonumber(l, -2)), fromLua(l, -1));
			}
		});
		return v;
		
	}
	/**
		Calls a lua function at `func` with `args`. If multipleReturns is true, return an array of results from the function, else return the first result

		If func is nil, the function at the top of the stack will be run
		If the lua function errors, a llua.LuaException will be thrown
	**/
	public static function callLuaFunction(l, ?func:String,?args:Array<Dynamic> = null,?multipleReturns:Bool=false):Dynamic {
		if(func != null) Lua.getglobal(l, func);
		if(args != null) {
			for(arg in args) Convert.toLua(l,arg);
		}
		LuaException.ifErrorThrow(l,Lua.pcall(l, args == null ? 0 : args.length, multipleReturns ? Lua.LUA_MULTRET : 1,0));

		if(!multipleReturns) return fromLua(l,fromLua(l,-1));
		final returnArray = [];
		for(i in -(Lua.gettop(l)-1)...0){
			returnArray.push(fromLua(l,i));
		}
		return returnArray;

	}
	/**
		Calls a lua function at `func` with `args`.

		If func is nil, the function at the top of the stack will be run
		If the lua function errors, a llua.LuaException will be thrown

		This is SLIGHTLY faster than callLuaFunction since it doesn't do any handling of returns. Useful for things like calling an event that doesn't return anything
	**/
	public static function callLuaFuncNoReturns(l, func:String,?args:Array<Dynamic> = null):Void {
		Lua.getglobal(l, func);
		if(args != null) for(arg in args) Convert.toLua(l,arg);
		
		LuaException.ifErrorThrow(l,Lua.pcall(l,args == null ? 0 : args.length, 0,0));
	}
}

// Anon_obj from hxcpp
@:include('hxcpp.h')
@:native('hx::Anon')
extern class Anon {

	@:native('hx::Anon_obj::Create')
	public static function create() : Anon;

	@:native('hx::Anon_obj::Add')
	public function add(k:String, v:Any):Void;

}
