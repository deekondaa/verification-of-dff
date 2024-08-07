class transaction;
  
  rand bit din;
  bit dout;
  
  function transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;
    
  endfunction
  
  function void display(input string tag);
    $display("[%0s] : DIN : %0b DOUT : %0b", tag, din, dout);
 
  endfunction
  
endclass

////////////////////////////


class generator;
  transaction tr;
  mailbox #(transaction) mbx;//sent to driver
  mailbox #(transaction) mbxref;//sent to scoreboard
  event sconext;
  event done;
  int count;
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
    tr = new();//create a new transaction object
    
  endfunction
  
  task run();
    repeat(count) begin
    assert(tr.randomize) else
      $display("Randomization failed");
    mbx.put(tr.copy);
    mbxref.put(tr.copy);
      
      tr.display("GEN");
      @(sconext);
    
    end
    -> done;
    
  endtask
  
endclass

//////////////////////

class driver;
  transaction tr;
  mailbox #(transaction) mbx;
  virtual dff_if vif;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task reset();
    vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 1'b0;
    @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
    
  endtask
  
  task run();
    forever begin
      mbx.get(tr);
      vif.din <= tr.din;
      @(posedge vif.clk);
      tr.display("DRV");
      vif.din <= 1'b0;
      @(posedge vif.clk);   
      
    end
    
  endtask 
  
  
endclass

//////////////////////////
class monitor;
  transaction tr;
  mailbox #(transaction) mbx;
  virtual dff_if vif;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    tr = new();
    forever begin
      repeat(2) @(posedge vif.clk);
      tr.dout = vif.dout;
      mbx.put(tr);
      tr.display("MON");
      
    end
    
  endtask
  
endclass

////////////////////////////

class scoreboard;
  transaction tr; //container to store data from MON
  transaction trref;//container to store data from GEN to compare
  mailbox #(transaction) mbx;//receive data from MON
  mailbox #(transaction) mbxref;//receive data from GEN
  event sconext;
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      mbxref.get(trref);
      tr.display("SCO");
      trref.display("REF");
      
      if(tr.dout == trref.din)
        $display("[SCO] : DATA MATCHED");
      else
        $display("[SCO] : DATA MISMATCH");
      $display("-----------------------------------------");
      ->sconext;
      
    end
    
  endtask
  
endclass

//////////////////////////

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event next;
  
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  mailbox #(transaction) mbxref;
  
  virtual dff_if vif;
  
  function new(virtual dff_if vif);
    gdmbx = new();
    mbxref = new();
    msmbx = new();
    
    gen = new(gdmbx, mbxref);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx, mbxref);
    this.vif = vif;
    drv.vif = vif;
    mon.vif = vif;
    gen.sconext = next;
    sco.sconext = next;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
      
    join_any
    
  endtask 
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
    
  endtask
  
  
  task run();
    pre_test();
    test();
    post_test();
    
  endtask
  
endclass


///////////////////////////////

module tb;
  
  dff_if vif();
  
  dff dut(vif);
  
  initial begin
    vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 10;
    env.run();
    
  end 
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end 
  
endmodule 
