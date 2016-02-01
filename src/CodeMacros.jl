#
# This file is a part of Code module. It contains macroses for 
# organism's code.
#
# @author DeadbraiN
#

#
# Returns random value by data type. e.g.: 123 for Int8
# @param {DataType} typ Data type
# @return {Any}
#
macro getValue(typ)
  :($typ !== ASCIIString ? rand($typ) : randstring())
end
#
# Checks if specified block belongs to specified function. We need 
# this for preventing inline blocks generation. For example if operator
# inside other if operator is impossible. So, if block belongs to
# specified function, then we may add other block based operator inside,
# otherwise we return Expr(:nothing) from current function.
# @param {Creature.Organism} org Organism we are working with
# @param {ASCIIString} fn Function String name
# @param {Expr} block Blockexpression we want to check
#
macro inFuncBlock(org, fn, block)
  :(if $block !== $org.vars[$fn].blocks[1] return Expr(:nothing) end)
end
#
# Checks if secified function is a main one. In other case we return
# Expr(:nothing) from current function.
# @param {ASCIIString} fn Function string name
#
macro inMainFunc(fn)
  :(if !isempty($fn) return Expr(:nothing) end)
end
#
# Creates new unique variable name and returns it's symbol
# @param {Creature.Organism} org Owner of new variable
# @return {Symbol}
#
macro getNewVar(org)
  :(symbol("var_", $org.varId += 1))
end
#
# Creates new unique custom function name.
# @param {Creature.Organism} org Organism we are working with
# @return {ASCIIString}
#
macro getNewFunc(org)
  :(string("func_", $org.fnId += 1))
end
#
# Returns one of supported types. Is used randomizer for choosing type.
# @return {DataType}
#
macro getType()
  local types::Array{DataType} = Helper.getSupportedTypes()
  :($types[rand(1:length($types))])
end
#
# Returns a variable from existing in a code
# @param {Creature.Organism} org Organism we are mutating
# @param {ASCIIString} fn An expression of parent(current) function within 
# we are orking in
# @param {DataType} typ Type of variable we want to take
# @return {Symbol}
#
macro getVar(org, fn, typ)
  :(if length($org.vars[$fn].vars[$typ]) < 1 return :nothing end; $org.vars[$fn].vars[$typ][rand(1:length($org.vars[$fn].vars[$typ]))])
end