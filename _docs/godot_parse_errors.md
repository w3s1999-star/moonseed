# Common Godot GDScript Parse Errors

## 1. Undeclared Identifier
- **Error:** Identifier "X" not declared in the current scope.
- **Cause:** Variable or function used before declaration, typo, or missing assignment.
- **Fix:** Declare the variable or check for typos.

## 2. Unexpected Token
- **Error:** Unexpected token "X" in file.
- **Cause:** Syntax error, misplaced symbol, or missing punctuation.
- **Fix:** Check for missing colons, parentheses, or indentation.

## 3. Indentation Error
- **Error:** Indentation error, expected indented block after statement.
- **Cause:** Incorrect indentation, mixing tabs and spaces.
- **Fix:** Use consistent indentation, usually tabs or spaces.

## 4. Unexpected End of File
- **Error:** Unexpected end of file.
- **Cause:** Unclosed block, missing 'end', or incomplete function.
- **Fix:** Ensure all blocks and functions are properly closed.

## 5. Invalid Syntax
- **Error:** Invalid syntax.
- **Cause:** Typo, misplaced operator, or wrong statement order.
- **Fix:** Review syntax and compare with documentation.

## 6. Type Mismatch
- **Error:** Cannot assign value of type X to variable of type Y.
- **Cause:** Assigning incompatible types.
- **Fix:** Cast or convert types as needed.

## 7. Function Not Found
- **Error:** Function "X" not found in base.
- **Cause:** Calling a function that does not exist or is misspelled.
- **Fix:** Check function name and definition.

## 8. Duplicate Declaration
- **Error:** Duplicate declaration of variable or function.
- **Cause:** Declaring the same variable or function twice.
- **Fix:** Remove duplicate declarations.

## 9. Invalid Assignment
- **Error:** Invalid assignment.
- **Cause:** Assigning to a constant or read-only property.
- **Fix:** Assign only to writable variables.

## 10. Invalid Call
- **Error:** Invalid call. Nonexistent function or wrong arguments.
- **Cause:** Calling a function with wrong number or type of arguments.
- **Fix:** Check function signature and arguments.

---

**Tip:** Always check the error message and the line number for quick diagnosis. Use Godot's built-in debugger and documentation for reference.