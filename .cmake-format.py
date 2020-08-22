# -----------------------------
# Options effecting formatting.
# -----------------------------
with section("format"):

  # How wide to allow formatted cmake files
  line_width = 71

  # How many spaces to tab for indent
  tab_size = 2

  # If true, separate flow control names from their parentheses with a space
  separate_ctrl_name_with_space = True

  # If true, separate function names from parentheses with a space
  separate_fn_name_with_space = False

  # If a statement is wrapped to more than one line, than dangle the closing
  # parenthesis on its own line.
  dangle_parens = True

  # If the trailing parenthesis must be 'dangled' on its on line, then align it
  # to this reference: `prefix`: the start of the statement,  `prefix-indent`:
  # the start of the statement, plus one indentation  level, `child`: align to
  # the column of the arguments
  dangle_align = 'prefix-indent'

