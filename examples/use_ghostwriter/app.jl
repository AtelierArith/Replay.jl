using Replay

instructions = """
"# Why We Created Julia";
"# We are greedy: we want more.)";
"# We want a language that's open source, with a liberal license.";
"# We want the speed of C with the dynamism of Ruby.";
"# We want a language that's homoiconic with true macros like Lisp, ";
"# but with obvious, familiar mathematical notation like Matlab.";
"# We want something as usable for general programming as Python, ";
"# as easy for statistics as R, ";
"# as natural for string processing as Perl, ";
"# as powerful for linear algebra as Matlab, ";
"# as good at gluing programs together as the shell.";
"# Something that is dirt simple to learn, ";
"# yet keeps the most serious hackers happy.";
"# We want it interactive and we want it compiled.)";
"(Did we mention it should be as fast as C?))";
"""

replay(instructions, use_ghostwriter=true)
