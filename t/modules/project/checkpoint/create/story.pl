
use Sparrow::Constants;

print `sparrow check add foo100 bar`;

-d sparrow_root."/projects/foo100/checkpoints/bar" and print "directory projects/foo100/checkpoints/bar exists\n";

