// TODO: Implement reset behavior
module handshake_slave #(parameter
			 ALWAYS_READY=1,
			 CONTINUOUS_READY=1,
			 FAIL_ON_MISMATCH=0,
			 VERBOSE="FALSE",
			 IFACE_NAME="handshake_slave"
) (conn);
  handshake_if conn;

  typedef struct packed {
    logic [conn.DATA_BITS-1:0] data;
  } handshake_slave_beat_t;

  typedef mailbox #(handshake_slave_beat_t) handshake_inbox_t;

  handshake_inbox_t handshake_inbox = new();
  handshake_inbox_t handshake_expect_inbox = new();

  handshake_slave_beat_t empty_beat = '{'0};

  /**************************************************************************
   * Read a single valid beat from the bus and insert it into the mailbox.
   **************************************************************************/
  task read_beat;
    handshake_slave_beat_t temp_check;

    begin
      $timeformat(-9, 2, " ns", 20);

      // Set ready signal
      conn.ready <= '1;

      // Wait for handshake to complete
      while (conn.valid != '1 || conn.ready != '1) begin
	if (VERBOSE == "TRUE") begin
	  $display("%t: %s - Waiting on handshake...", $time, IFACE_NAME, conn.ready, conn.valid);
	end

	@(posedge conn.clk);
      end

      // If we don't care about a mismatch
      if(FAIL_ON_MISMATCH == 0) begin
	// If no expected beat present, only output the data received
	if(handshake_expect_inbox.num() == 0) begin
	  if(VERBOSE == "TRUE") begin
	    $display("%t: %s - Received: '%x' [WARNING - No expected data]", $time, IFACE_NAME, conn.data);
	  end

	  // Compare if present, but only output a warning if mismatch
	end else begin
	  // Get the expected beat
	  handshake_expect_inbox.get(temp_check);

	  if (VERBOSE == "TRUE") begin
	    // Compare the received and expected
	    if(temp_check.data == conn.data) begin
	      $display("%t: %s - Received: '%x' - Expected: '%x'", $time, IFACE_NAME, conn.data, temp_check.data);
	    end else begin
	      $display("%t: %s - Received: '%x' - Expected: '%x' [WARNING - MISMATCH]", $time, IFACE_NAME, conn.data, temp_check.data);
	    end
          end
	end

        // We do care about a mismatch
      end else begin
	if(handshake_expect_inbox.num() == 0) begin
	  // Fail, no expected beat, but a beat was found
	  $display("%t: %s - Received: '%x' - Expected: '' [ERROR - No expected data]", $time, IFACE_NAME, conn.data);
	  $fatal("No data expected on %s, found: '%x'", IFACE_NAME, conn.data);

	end else begin
	  // Get the expected beat
	  handshake_expect_inbox.get(temp_check);
	  assert(conn.data == temp_check.data);
	  $display("%t: %s - Received: '%x'", $time, IFACE_NAME, conn.data);
	  $display("%t: %s - Expected: '%x'", $time, IFACE_NAME, temp_check.data);
	  $fatal("No data expected on %s, found: '%x'", IFACE_NAME, conn.data);
	end // else: !if(handshake_expect_inbox.num() == 0)
      end // else: !if(FAIL_ON_MISMATCH == 0)

      // Save the received beat to the received beats inbox
      handshake_inbox.put(conn.data);

      // Set ready signal low if not expecting any additional transactions,
      // otherwise keep it high in expectation of next transaction.
      if(handshake_expect_inbox.num() == 0 && ALWAYS_READY == 0) begin
	// If not continuous ready, drop ready after ever valid beat
	if(CONTINUOUS_READY==0) begin
	  conn.ready <= '0;

	  // Else continuous ready
	end else begin
	  // If valid, remain ready for next beat
	  if(conn.valid == '1) begin
	    conn.ready <= '1;

	    // If valid dropped, drop ready as well
	  end else begin
	    conn.ready <= '0;

	  end
	end

      end else begin
	conn.ready <= '1;
      end
    end
  endtask // read_beat


  /**************************************************************************
   * Get a beat from the mailbox when one is available. [Blocking]
   **************************************************************************/
  task get_beat;
    output logic [conn.DATA_BITS-1:0] data;

    handshake_slave_beat_t temp;

    begin
      handshake_inbox.get(temp);

      // Write output beat
      data  = temp.data;
    end
  endtask


  /**************************************************************************
   * Expect a beat from the master. [Non-blocking]
   **************************************************************************/
  task expect_beat;
    input logic [conn.DATA_BITS-1:0] data;

    begin
      // Put the expected transaction data in the expected transaction
      // mailbox.
      handshake_expect_inbox.put(data);

      // Set the slave ready high now that we're expecting a transaction
      conn.ready <= '1;
    end
  endtask


  /**************************************************************************
   * Main runtime loop
   **************************************************************************/
  initial begin
    $timeformat(-9, 2, " ns", 20);
    conn.ready  = '0;

    forever begin
      if(conn.arstn == '1) begin
	if(ALWAYS_READY==0) begin
	  @(posedge conn.clk);
	  if(CONTINUOUS_READY==1 && conn.valid == '0) begin
	    conn.ready <= '0;

	  end else if(conn.valid == '1 || conn.ready == '1) begin
	    read_beat();

	  end

	end else begin
	  @(posedge conn.clk);
	  read_beat();

	end
      end else begin // if (conn.arstn == '1)
	// Wait for the next clock cycle
	@(posedge conn.clk);

      end // else: !if(conn.arstn == '1)
    end // forever begin
  end // initial begin


endmodule // handshake_slave_bfm
