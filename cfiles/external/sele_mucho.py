from pymol import cmd,stored
#stored.list = []
cmd.select("s0", "id and 1mtn")
cmd.select("s1", "id and 1mtn")
cmd.select("s2", "id and 1mtn")
cmd.select("todo", "s0 or s1 or s2")
cmd.delete("s0 or s1 or s2")


