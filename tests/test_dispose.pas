program TestDispose;
{ Stress test for new(...) / dispose(...) reclaim.

  Default heap_limit in pvm.s is 0x00F000 (~60 KiB). The minimum block
  size in sys_alloc is 12 bytes (header + payload). An alloc-only loop
  would TRAP 5 (heap-overflow) around 5000 iterations.

  This test loops 10000 alloc+dispose pairs (2x heap capacity). If
  dispose actually returns blocks to the free list, every iteration's
  fresh alloc reuses a freed block and the heap pointer stays bounded.
  If dispose were a no-op or broken, this would TRAP 5 around iteration
  5000.

  Prints "DISPOSE_OK" on success. Any output other than that on the
  output line means the toolchain or runtime is broken. }

const
  ITER = 10000;

type
  PNode = ^Node;
  Node = record
    val: integer;
    next: PNode
  end;

var
  i: integer;
  p: PNode;

begin
  i := 0;
  while i < ITER do begin
    new(p);
    p^.val := i;
    p^.next := nil;
    dispose(p);
    i := i + 1
  end;
  writeln('DISPOSE_OK')
end.
