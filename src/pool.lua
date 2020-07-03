#!/usr/bin/env lua
-- ====================================================================== --
-- POOL (Poorman's object-oriented lua)    MIT License (c) 2019 Josh Feng --
local pairs, error, tostring, type, getmetatable, setmetatable, rawset =
      pairs, error, tostring, type, getmetatable, setmetatable, rawset -- for efficiency

local function cloneTbl (src, mt) -- {{{ deep copy the string-key-ed
    local targ = {}
    for k, v in pairs(src) do
        if 'string' == type(k) then
            targ[k] = type(v) == 'table' and cloneTbl(v, mt and getmetatable(v)) or v
        end
    end
    if mt then setmetatable(targ, mt) end -- No trace of src, since object is flat
    return targ
end -- }}}

local function setVar (t, k, v) -- forbid creating vars -- {{{
    if t[k] == nil then error('Undefined in class:'..tostring(t), 2) end
    rawset(t, k, v)
end -- }}}
local function annihilator (o, ...) -- {{{ destructor for objects
    local mt = getmetatable(o)
    while mt do
        if mt['>'] then mt['>'](o) end -- rawget is not necessary
        mt = getmetatable(mt.__index)
    end
end -- }}} NB: not collected by gc immediately
local function polymorphism (o, mt, ...) -- {{{ constructor for objects
    local mtt = mt.__index -- metatable template
    if mtt then
        for _, v in pairs(mtt) do -- dupe table
            if o[_] == v and type(v) == 'table' then o[_] = cloneTbl(v) end
        end
        mtt = getmetatable(mtt)
        if mtt then polymorphism(o, mtt, ...) end
    end
    if mt['<'] then mt['<'](o, ...) end -- rawget is not necessary
end -- }}}

local class = {
    id = ''; -- version control
    list = {}; -- class record
    copy = function (c, o) -- duplicate object o
        return cloneTbl(o, getmetatable(o) or error('bad object', 2))
    end;
}

function class:new (o, ...) -- {{{ duplicate the object
    o = (getmetatable(o) or error('bad object', 2))[1] -- class creator
    if not self.list[o] then error('bad object', 2) end
    return o(...)
end -- }}}
function class:parent (o) -- {{{ parent class
    o = (type(o) == 'table' and getmetatable(o) or self.list[o]) or error('bad object/class', 2)
    o = getmetatable(o.__index)
    return o and o[1] -- parent class creator
end -- }}}

setmetatable(class, {
    __metatable = true;
    __call = function (c, tmpl) -- class {{{
        if 'table' ~=  type(tmpl) then error('Class declaration:'..tostring(t), 2) end
        if tmpl['<'] and type(tmpl['<']) ~= 'function' then error(' bad constructor', 2) end
        if tmpl['>'] and type(tmpl['>']) ~= 'function' then error(' bad destructor', 2) end
        local omt, creator = {}, (type(tmpl[1]) == 'table') and tmpl[1][1]
        if creator then -- baseClass
            creator = c.list[creator] or error('bad base class: '..tostring(tmpl[1][1]), 2)
            for k, v in pairs(creator) do omt[k] = v end -- inherite operators
        else
            omt.__newindex = setVar -- forbid new field addition
            omt.__gc = annihilator
        end
        if type(tmpl[1]) == 'table' then
            for k, v in pairs(tmpl[1]) do -- newly defined operators
                if type(k) == 'string' then omt[k] = v end
            end
        end
        tmpl = cloneTbl(tmpl) -- class template closure
        -- polymorphism & remove their access from object
        omt['<'], omt['>'], tmpl['<'], tmpl['>'] = tmpl['<'], tmpl['>'], nil, nil
        if creator then
            creator.__gc = nil -- disable extra tmpl destructor
            setmetatable(tmpl, creator)
            creator.__gc = annihilator -- recover
        end
        omt.__index = tmpl

        creator = function (...) -- classes {{{ tmpl is the hidden class template
            local o = {}
            setmetatable(o, omt) -- need member functions
            polymorphism(o, omt, ...)
            return o -- the object
        end -- }}}
        c.list[creator] = omt
        omt[1] = creator
        return creator
    end; -- }}}
})

return class
-- ====================================================================== --
-- vim: ts=4 sw=4 sts=4 et foldenable fdm=marker fmr={{{,}}} fdl=1
