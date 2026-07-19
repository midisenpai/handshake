module handshake_master #(parameter
			  IFACE_NAME="handshake_master",
			  VERBOSE="FALSE"
			  ) (conn);
   handshake_if conn;

   typedef struct packed {
      logic [conn.DATA_BITS-1:0] data;
      logic                      valid;
      logic			 ready;
   } handshake_master_beat_t;

   typedef mailbox 		   #(handshake_master_beat_t) handshake_inbox_t;

   handshake_inbox_t handshake_inbox  = new();
   handshake_inbox_t handshake_expect = new();

   handshake_master_beat_t empty_beat = '{default: '0};
   handshake_master_beat_t temp_beat;


   /**************************************************************************
    * Writes a beat to the handshake BFM output lines
    **************************************************************************/
   task write_beat;
      input handshake_master_beat_t temp;

      begin
	 // Write output beat
	 conn.valid  <= temp.valid;
	 conn.data   <= temp.data;

      end
   endtask // write_beat


   /**************************************************************************
    * Add a beat to the queue of handshake beats to be written
    **************************************************************************/
   task put_beat;
      input logic [conn.DATA_BITS-1:0]  data;
      input logic			valid;

      handshake_master_beat_t temp;

      begin
	 temp.valid = valid;
	 temp.data  = data;

	 // Add output beat to mailbox
	 handshake_inbox.put(temp);
	 handshake_expect.put(temp);

      end
   endtask // put_beat


   /**************************************************************************
    * Get the oldest beat written to the queue of handshake beats.
    **************************************************************************/
   task get_beat;
      output logic [conn.DATA_BITS-1:0] data;

      handshake_master_beat_t temp;

      begin
	 // Get output beat from mailbox
	 handshake_expect.get(temp);

	 // Assign beat values to outputs
	 data  = temp.data;

      end
   endtask // get_beat


   /**************************************************************************
    * Add a basic beat to the queue of handshake beats to be written. A basic beat
    * only requires data and last to be specified.
    **************************************************************************/
   task put_simple_beat;
      input logic [conn.DATA_BITS-1:0] data;

      begin
	 put_beat(.valid('1),
		  .data(data));
      end
   endtask // put_simple_beat



   initial begin
      $timeformat(-9, 2, " ns", 20);

      conn.valid = '0;
      conn.data  = '0;

      #1;

      forever begin
	 if(conn.arstn == '1) begin
	    if(handshake_inbox.try_get(temp_beat) != 0) begin
	       write_beat(temp_beat);

	       if (VERBOSE == "TRUE") begin
		  $display("%t: %s - Write Data - '%X'", $time, IFACE_NAME, temp_beat.data);
	       end

	       @(negedge conn.clk)
		 if(conn.ready == '0) begin
		    wait(conn.ready == '1);
		 end

	       // Wait for device ready
	       @(posedge conn.clk && conn.ready == '1);

	    end else begin
	       write_beat(empty_beat);

	       // Wait for the next clock cycle
	       @(posedge conn.clk);

	    end
	 end else begin // if (conn.arstn == '1)
	    // Wait for the next clock cycle
	    @(posedge conn.clk);
	    
	 end // else: !if(conn.arstn == '1)
      end // forever begin
   end

endmodule // handshake_master_bfm
