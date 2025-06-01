---@class Cartethyia.Parser
local parser = {}

--[[
The complete CMake syntax
https://cmake.org/cmake/help/v4.0/manual/cmake-language.7.html

file                =  file_element*
file_element        =  command_invocation line_ending |
					   (bracket_comment|space)* line_ending
line_ending         =  line_comment? newline
space               =  <match '[ \t]+'>
newline             =  <match '\n'>
command_invocation  =  space* identifier space* '(' arguments ')'
identifier          =  <match '[A-Za-z_][A-Za-z0-9_]*'>
arguments           =  argument? separated_arguments*
separated_arguments =  separation+ argument? |
					   separation* '(' arguments ')'
separation          =  space | line_ending
argument            =  bracket_argument | quoted_argument | unquoted_argument
bracket_argument    =  bracket_open bracket_content bracket_close
bracket_open        =  '[' '='* '['
bracket_content     =  <any text not containing a bracket_close with
						the same number of '=' as the bracket_open>
bracket_close       =  ']' '='* ']'
quoted_argument     =  '"' quoted_element* '"'
quoted_element      =  <any character except '\' or '"'> |
					   escape_sequence |
					   quoted_continuation
quoted_continuation =  '\' newline
unquoted_argument   =  unquoted_element+
unquoted_element    =  <any character except whitespace or one of '()#"\'> |
					   escape_sequence
escape_sequence     =  escape_identity | escape_encoded | escape_semicolon
escape_identity     =  '\' <match '[^A-Za-z0-9;]'>
escape_encoded      =  '\t' | '\r' | '\n'
escape_semicolon    =  '\;'
bracket_comment     =  '#' bracket_argument
line_comment        =  '#' <any text not starting in a bracket_open
					   and not containing a newline>
]]

---@class Cartethyia.Parser.Command
---@field public name string Name of the command to be invoked.
---@field public line integer Line number of the command.
---@field public arguments Cartethyia.Parser.Argument[] List of arguments passed to the command.

---@class Cartethyia.Parser.Argument
---@field public argument string The argument string.
---@field public type "bracket"|"quoted"|"unquoted" Kind of the argument type.
---@field public line integer Line number of the argument.
---@field public column integer Column number of the argument relative to the file.

---@class Cartethyia.Parser.Error
---@field public message string
---@field public line integer
---@field public column integer

---@class Cartethyia.Parser.LineInfo
---@field public line integer
---@field public column integer

---@param text string
---@param literal string
---@package
function parser.countCharacters(text, literal)
	local count = 0
	local start = 1

	while true do
		local s, e = text:find(literal, start, true)
		if not s then
			break
		end
		count = count + 1
		start = e + 1
	end

	return count
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseSpace(text, lineinfo)
	local s, e = text:find("^[ \t]+")
	if s and e then
		lineinfo.column = lineinfo.column + e
		return text:sub(1, e), text:sub(e + 1)
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseIdentifier(text, lineinfo)
	local s, e = text:find("^[A-Za-z_][A-Za-z0-9_]*")
	if s and e then
		lineinfo.column = lineinfo.column + e
		return text:sub(1, e), text:sub(e + 1)
	end

	return nil, text
end

---@param literal string
---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.matchLiteral(literal, text, lineinfo)
	if text:sub(1, #literal) == literal then
		lineinfo.column = lineinfo.column + #literal
		return literal, text:sub(#literal + 1)
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseNewline(text, lineinfo)
	if text:sub(1, 2) == "\r\n" then
		lineinfo.line = lineinfo.line + 1
		lineinfo.column = 1
		return "\r\n", text:sub(3)
	elseif text:sub(1, 1) == "\n" then
		lineinfo.line = lineinfo.line + 1
		lineinfo.column = 1
		return "\n", text:sub(2)
	else
		return nil, text
	end
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseBracketOpen(text, lineinfo)
	local s, e = text:find("^%[=*%[")
	if s and e then
		lineinfo.column = lineinfo.column + e
		return e - 2, text:sub(e + 1)
	end

	return nil, text
end

---@param text string
---@param nequalsign integer
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseBracketContentAndClose(text, nequalsign, lineinfo)
	local s, e = text:find("]"..string.rep("=", nequalsign).."]", 1, true)
	if s and e then
		local content = text:sub(1, s - 1)

		local newlinecount = parser.countCharacters(content, "\n")
		if newlinecount > 0 then
			lineinfo.line = lineinfo.line + newlinecount
			-- Find how many columns are skipped for content
			lineinfo.column = 1 + #(content:reverse():match("^([^\n]+)") or "")
		else
			lineinfo.column = lineinfo.column + s - 1
		end

		lineinfo.column = lineinfo.column + 2 + nequalsign
		return content, text:sub(e + 1)
	end

	---@type Cartethyia.Parser.Error
	local err = {
		line = lineinfo.line,
		column = lineinfo.column,
		message = "missing matching closing bracket"
	}
	return nil, text, err
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseBracketArgument(text, lineinfo)
	local nequalsign

	nequalsign, text = parser.parseBracketOpen(text, lineinfo)
	if not nequalsign then
		return nil, text, nil
	end

	local content, err
	content, text, err = parser.parseBracketContentAndClose(text, nequalsign, lineinfo)
	if not content then
		return nil, text, err
	end

	return content, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@param includenewline boolean
---@package
function parser.parseEscapeSequence(text, lineinfo, includenewline)
	local next = text:sub(1, 1)

	lineinfo.column = lineinfo.column + 1
	if next == "" then
		lineinfo.column = lineinfo.column - 1
		---@type Cartethyia.Parser.Error
		local err = {
			line = lineinfo.line,
			column = lineinfo.column - 1,
			message = "unexpected escape character in quoted argument"
		}
		return nil, text, err
	elseif next == "t" then
		return "\t", text:sub(2)
	elseif next == "r" then
		return "\r", text:sub(2)
	elseif next == "n" then
		return "\n", text:sub(2)
	elseif text:sub(1, 2) == "\r\n" then
		if includenewline then
			-- empty string
			return "", text:sub(3)
		else
			return nil, text
		end
	elseif next == "\n" then
		if includenewline then
			-- empty string
			return "", text:sub(2)
		else
			return nil, text
		end
	elseif next:match("^[^A-Za-z0-9;]") then
		-- Literal
		return "\\"..next, text:sub(2)
	else
		-- Invalid escape character
		lineinfo.column = lineinfo.column - 1
		local err = {
			line = lineinfo.line,
			column = lineinfo.column,
			message = "invalid escape sequence '\\"..next.."'"
		}
		return nil, text, err
	end
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseQuotedArgument(text, lineinfo)
	local dummy
	local line, column = lineinfo.line, lineinfo.column

	dummy, text = parser.matchLiteral("\"", text, lineinfo)
	if not dummy then
		return nil, text
	end

	---@type string[]
	local content = {}
	-- This is quoted element
	while true do
		if #text == 0 then
			---@type Cartethyia.Parser.Error
			local err = {
				line = line,
				column = column,
				message = "unclosed quoted argument"
			}
			return nil, text, err
		end

		local character = text:sub(1, 1)
		text = text:sub(2)

		lineinfo.column = lineinfo.column + 1

		if character == "\n" then
			lineinfo.line = lineinfo.line + 1
			lineinfo.column = 1
			content[#content+1] = character
		elseif character == "\\" then
			-- Escape sequence
			local escape, err
			escape, text, err = parser.parseEscapeSequence(text, lineinfo, true)
			if escape then
				if #escape > 0 then
					content[#content+1] = escape
				end
			else
				return nil, text, err
			end
		elseif character == "\"" then
			break
		else
			content[#content+1] = character
		end
	end

	return table.concat(content), text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseLineComment(text, lineinfo)
	if text:sub(1, 1) == "#" then
		lineinfo.column = lineinfo.column + 1

		if text:sub(2, 2) == "[" then
			-- Bracket comments
			lineinfo.column = lineinfo.column - 1
			return nil, text
		end

		text = text:sub(2)

		-- Line comment
		local s = text:find("\r\n", 1, true) or text:find("\n", 1, true)

		if s then
			lineinfo.column = lineinfo.column + s - 1
			return text:sub(1, s - 1), text:sub(s)
		else
			lineinfo.column = lineinfo.column + #text
			return text, ""
		end
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseBracketComment(text, lineinfo)
	if text:sub(1, 1) == "#" then
		lineinfo.column = lineinfo.column + 1

		if text:sub(2, 2) == "[" then
			-- Bracket comment
			return parser.parseBracketArgument(text:sub(2), lineinfo)
		else
			-- Line comment
			lineinfo.column = lineinfo.column - 1
			return nil, text
		end
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseUnquotedElement(text, lineinfo)
	---@type string[]
	local content = {}
	local line, column = lineinfo.line, lineinfo.column

	while true do
		if #text == 0 then
			---@type Cartethyia.Parser.Error
			local err = {
				line = line,
				column = column,
				message = "unexpected end of file"
			}
			return nil, text, err
		end

		local character = text:sub(1, 1)

		lineinfo.column = lineinfo.column + 1

		if character:find("%s") or character == "(" or character == ")"or character == "#" then
			lineinfo.column = lineinfo.column - 1
			break
		elseif character == "\\" then
			-- Escape sequence
			text = text:sub(2)

			local escape, err
			escape, text, err = parser.parseEscapeSequence(text, lineinfo, false)
			if escape then
				if #escape > 0 then
					content[#content+1] = escape
				end
			elseif err then
				return nil, text, err
			else
				content[#content+1] = "\\"
				break
			end
		else
			text = text:sub(2)
			content[#content+1] = character
		end
	end

	local result = table.concat(content)
	if #result > 0 then
		return result, text
	else
		return nil, text
	end
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseUnquotedArgument(text, lineinfo)

	local result, err
	result, text, err = parser.parseUnquotedElement(text, lineinfo)
	if result and #result > 0 then
		return result, text
	else
		return nil, text, err
	end
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseArgument(text, lineinfo)
	local argument, err
	local line, column = lineinfo.line, lineinfo.column

	-- Bracket argument
	argument, text, err = parser.parseBracketArgument(text, lineinfo)
	if argument then
		---@type Cartethyia.Parser.Argument
		local result = {
			argument = argument,
			type = "bracket",
			line = line,
			column = column
		}
		return result, text
	elseif err then
		return nil, text, err
	end

	-- Quoted argument
	argument, text, err = parser.parseQuotedArgument(text, lineinfo)
	if argument then
		---@type Cartethyia.Parser.Argument
		local result = {
			argument = argument,
			type = "quoted",
			line = line,
			column = column
		}
		return result, text
	elseif err then
		return nil, text, err
	end

	-- Unquoted argument
	argument, text, err = parser.parseUnquotedArgument(text, lineinfo)
	if argument then
		---@type Cartethyia.Parser.Argument
		local result = {
			argument = argument,
			type = "unquoted",
			line = line,
			column = column
		}
		return result, text
	elseif err then
		return nil, text, err
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseLineEnding(text, lineinfo)
	local _
	_, text = parser.parseSpace(text, lineinfo)
	_, text = parser.parseLineComment(text, lineinfo)

	return parser.parseNewline(text, lineinfo)
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseSeparation(text, lineinfo)
	local spcORnewline
	spcORnewline, text = parser.parseSpace(text, lineinfo)
	if spcORnewline then
		return spcORnewline, text
	end

	spcORnewline, text = parser.parseLineEnding(text, lineinfo)
	if spcORnewline then
		return spcORnewline, text
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@param output Cartethyia.Parser.Argument[]
---@package
function parser.parseSeparatedArguments(text, lineinfo, output)
	-- Test "separation+"
	local sepcount = 0
	while true do
		-- Test any comment
		local dummy, err
		dummy, text, err = parser.parseAnyComment(text, lineinfo)
		if err then
			return nil, text, err
		end

		local sep
		sep, text = parser.parseSeparation(text, lineinfo)
		if not sep then
			break
		end

		sepcount = sepcount + 1

		-- Test any comment again
		dummy, text, err = parser.parseAnyComment(text, lineinfo)
		if err then
			return nil, text, err
		end
	end

	if sepcount > 0 then
		-- Try "argument?"
		local argument, err
		argument, text, err = parser.parseArgument(text, lineinfo)
		if argument then
			output[#output+1] = argument
			return output, text
		elseif err then
			return nil, text, err
		end
	end

	-- Test '(' arguments ')'"
	-- (We already tested for separation* above)
	local dummy, err
	dummy, text = parser.matchLiteral("(", text, lineinfo)
	if dummy then
		-- Add opening parenthesis as unquoted argument
		output[#output+1] = {
			argument = "(",
			type = "unquoted",
			line = lineinfo.line,
			column = lineinfo.column - 1
		}

		dummy, text, err = parser.parseArguments(text, lineinfo, output)
		if err then
			return nil, text, err
		end

		dummy, text = parser.matchLiteral(")", text, lineinfo)
		if not dummy then
			---@type Cartethyia.Parser.Error
			err = {
				line = lineinfo.line,
				column = lineinfo.column,
				message = "expected closing parenthesis"
			}
			return nil, text, err
		end
		-- Add closing parenthesis as unquoted argument
		output[#output+1] = {
			argument = ")",
			type = "unquoted",
			line = lineinfo.line,
			column = lineinfo.column - 1
		}

		return output, text
	end

	return nil, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@param output Cartethyia.Parser.Argument[]|nil
---@package
function parser.parseArguments(text, lineinfo, output)
	if not output then
		output = {}
	end

	-- Consume bracket comment
	local comment, err
	comment, text, err = parser.parseBracketComment(text, lineinfo)
	if err then
		return nil, text, err
	end

	local argument
	argument, text, err = parser.parseArgument(text, lineinfo)
	if argument then
		output[#output+1] = argument
	elseif err then
		return nil, text, err
	end

	-- Consume bracket comment again
	comment, text, err = parser.parseBracketComment(text, lineinfo)
	if err then
		return nil, text, err
	end

	-- Consume as many separated arguments as possible
	while true do
		local dummy
		dummy, text, err = parser.parseSeparatedArguments(text, lineinfo, output)

		if err then
			return nil, text, err
		end

		if not dummy then
			break
		end
	end

	return output, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseCommandInvocation(text, lineinfo)
	local dummy, identifier, err

	-- Remove preceding space
	dummy, text = parser.parseSpace(text, lineinfo)

	identifier, text = parser.parseIdentifier(text, lineinfo)
	if not identifier then
		---@type Cartethyia.Parser.Error
		err = {
			line = lineinfo.line,
			column = lineinfo.column,
			message = "expected identifier"
		}
		return nil, text
	end

	local line = lineinfo.line

	-- Remove trailing space
	dummy, text = parser.parseSpace(text, lineinfo)

	-- Opening args
	dummy, text = parser.matchLiteral("(", text, lineinfo)
	if not dummy then
		---@type Cartethyia.Parser.Error
		err = {
			line = lineinfo.line,
			column = lineinfo.column,
			message = "expected opening parenthesis"
		}
		return nil, text, err
	end

	-- Arguments
	local args
	args, text, err = parser.parseArguments(text, lineinfo)
	if err then
		return nil, text, err
	end
	assert(args)

	-- Closing args
	dummy, text = parser.matchLiteral(")", text, lineinfo)
	if not dummy then
		---@type Cartethyia.Parser.Error
		err = {
			line = lineinfo.line,
			column = lineinfo.column,
			message = "expected closing parenthesis"
		}
		return nil, text, err
	end

	---@type Cartethyia.Parser.Command
	local result = {
		name = identifier,
		line = line,
		arguments = args
	}
	return result, text
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseAnyComment(text, lineinfo)
	local comment, err
	comment, text, err = parser.parseBracketComment(text, lineinfo)
	if err then
		return nil, text, err
	elseif comment then
		return comment, text
	end

	return parser.parseLineComment(text, lineinfo)
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseFileElement(text, lineinfo)
	local command, err
	command, text, err = parser.parseCommandInvocation(text, lineinfo)

	if err then
		return nil, text, err
	end

	-- Maybe a comment
	while true do
		local comment
		comment, text, err = parser.parseBracketComment(text, lineinfo)

		if err then
			return nil, text, err
		elseif not comment then
			local space
			space, text = parser.parseSpace(text, lineinfo)

			if not space then
				break
			end
		end
	end

	local needNewlineForCommand = not not command

	while true do
		local lineend
		lineend, text = parser.parseLineEnding(text, lineinfo)
		if not lineend then
			if needNewlineForCommand then
				---@type Cartethyia.Parser.Error
				err = {
					line = lineinfo.line,
					column = lineinfo.column,
					message = "expected newline"
				}

				return nil, text, err
			else
				break
			end
		end

		needNewlineForCommand = false
	end

	if command then
		return command, text
	else
		return true, text
	end
end

---@param text string
---@param lineinfo Cartethyia.Parser.LineInfo
---@package
function parser.parseFile(text, lineinfo)
	---@type Cartethyia.Parser.Command[]
	local commands = {}

	while #text > 0 do
		local command, err
		command, text, err = parser.parseFileElement(text, lineinfo)

		if not command then
			if err then
				return nil, err
			else
				break
			end
		end

		if type(command) == "table" then
			commands[#commands+1] = command
		end
	end

	return commands
end

---@param text string
function parser.parse(text)
	local lineinfo = {line = 1, column = 1}
	if text:sub(1, 3) == "\239\187\191" then
		-- Remove BOM
		text = text:sub(4)
	end

	return parser.parseFile(text, lineinfo)
end

return parser
