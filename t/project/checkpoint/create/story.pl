
use Sparrow::Constants;

print `sparrow project remove foo100`;
print `sparrow project create foo100`;


-d sparrow_root."/projects/foo100" and print "directory projects/foo100 exists\n";
-d sparrow_root."/projects/foo100/checkpoints" and print "directory projects/foo100/checkpoints exists\n";

print `sparrow project check_add foo100 bar`;

-d sparrow_root."/projects/foo100/checkpoints/bar" and print "directory projects/foo100/checkpoints/bar exists\n";

