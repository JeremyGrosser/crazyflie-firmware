package body UART_Syslink is

   --  Public procedures and functions

   procedure UART_Syslink_Init is
   begin
      Initialize_GPIO_Port_Pins;
      Initialize_USART;
      Initialize_DMA;

      Enable (Transceiver);
   end UART_Syslink_Init;

   procedure UART_Get_Data_With_Timeout
     (Rx_Byte     : out T_Uint8;
      Has_Succeed : out Boolean) is
      Timeout_Time : Time;
   begin
      Timeout_Time := Clock + UART_DATA_TIMEOUT_MS;
      while Clock <= Timeout_Time loop
         Rx_Queue.Dequeue_Item (Rx_Byte, Has_Succeed);
         if Has_Succeed then
            return;
         end if;
      end loop;
   end UART_Get_Data_With_Timeout;

   procedure UART_Send_DMA_Data
     (Data_Size : Natural;
      Data      : DMA_Data) is
   begin

   end UART_Send_DMA_Data;

   --  Private procedures and functions

   procedure Initialize_GPIO_Port_Pins is
      Configuration : GPIO_Port_Configuration;
   begin
      Enable_Clock (IO_Port);

      Configuration.Mode := Mode_AF;
      Configuration.Speed := Speed_50MHz;
      Configuration.Output_Type := Push_Pull;
      Configuration.Resistors := Pull_Up;

      Configure_IO
        (Port   => IO_Port,
         Pins   => Rx_Pin & Tx_Pin,
         Config => Configuration);

      Configure_Alternate_Function
        (Port => IO_Port,
         Pins => Rx_Pin & Tx_Pin,
         AF   => Transceiver_AF);
   end Initialize_GPIO_Port_Pins;

   procedure Initialize_USART is
   begin
      Enable_Clock (Transceiver);

      Enable (Transceiver);

      Set_Baud_Rate    (Transceiver, 115_200);
      Set_Mode         (Transceiver, Tx_Mode);
      Set_Stop_Bits    (Transceiver, Stopbits_1);
      Set_Word_Length  (Transceiver, Word_Length_8);
      Set_Parity       (Transceiver, No_Parity);
      Set_Flow_Control (Transceiver, No_Flow_Control);
   end Initialize_USART;

   procedure Initialize_DMA is
      Configuration : DMA_Stream_Configuration;
   begin
      Enable_Clock (Controller);

      Configuration.Channel                      := Tx_Channel;
      Configuration.Direction                    := Memory_To_Peripheral;
      Configuration.Increment_Peripheral_Address := False;
      Configuration.Increment_Memory_Address     := True;
      Configuration.Peripheral_Data_Format       := Bytes;
      Configuration.Memory_Data_Format           := Bytes;
      Configuration.Operation_Mode               := Normal_Mode;
      Configuration.Priority                     := Priority_Very_High;
      Configuration.FIFO_Enabled                 := True;
      Configuration.FIFO_Threshold               := FIFO_Threshold_Full_Configuration;
      Configuration.Memory_Burst_Size            := Memory_Burst_Inc4;
      Configuration.Peripheral_Burst_Size        := Peripheral_Burst_Inc4;

      Configure (Controller, Tx_Stream, Configuration);
      --  note the controller is disabled by the call to Configure
   end Initialize_DMA;

    -------------------------------
   -- Finalize_DMA_Transmission --
   -------------------------------

   procedure Finalize_DMA_Transmission (Transceiver : in out USART) is
      --  see static void USART_DMATransmitCplt
   begin
      loop
         exit when Status (Transceiver, Transmission_Complete_Indicated);
      end loop;
      Clear_Status (Transceiver, Transmission_Complete_Indicated);
      Disable_DMA_Transmit_Requests (Transceiver);
   end Finalize_DMA_Transmission;

   --  Tasks and protected objects

   protected body Tx_IRQ_Handler is

      entry Await_Event (Occurrence : out DMA_Interrupt) when Event_Occurred is
      begin
         Occurrence := Event_Kind;
         Event_Occurred := False;
      end Await_Event;

      procedure IRQ_Handler is
      begin
         --  Transfer Error Interrupt management
         if Status (Controller, Tx_Stream, Transfer_Error_Indicated) then
            if Interrupt_Enabled (Controller, Tx_Stream, Transfer_Error_Interrupt) then
               Disable_Interrupt (Controller, Tx_Stream, Transfer_Error_Interrupt);
               Clear_Status (Controller, Tx_Stream, Transfer_Error_Indicated);
               Event_Kind := Transfer_Error_Interrupt;
               Event_Occurred := True;
               return;
            end if;
         end if;

         --  FIFO Error Interrupt management
         if Status (Controller, Tx_Stream, FIFO_Error_Indicated) then
            if Interrupt_Enabled (Controller, Tx_Stream, FIFO_Error_Interrupt) then
               Disable_Interrupt (Controller, Tx_Stream, FIFO_Error_Interrupt);
               Clear_Status (Controller, Tx_Stream, FIFO_Error_Indicated);
               Event_Kind := FIFO_Error_Interrupt;
               Event_Occurred := True;
               return;
            end if;
         end if;

         --  Direct Mode Error Interrupt management
         if Status (Controller, Tx_Stream, Direct_Mode_Error_Indicated) then
            if Interrupt_Enabled (Controller, Tx_Stream, Direct_Mode_Error_Interrupt) then
               Disable_Interrupt (Controller, Tx_Stream, Direct_Mode_Error_Interrupt);
               Clear_Status (Controller, Tx_Stream, Direct_Mode_Error_Indicated);
               Event_Kind := Direct_Mode_Error_Interrupt;
               Event_Occurred := True;
               return;
            end if;
         end if;

         --  Half Transfer Complete Interrupt management
         if Status (Controller, Tx_Stream, Half_Transfer_Complete_Indicated) then
            if Interrupt_Enabled (Controller, Tx_Stream, Half_Transfer_Complete_Interrupt) then
               if Double_Buffered (Controller, Tx_Stream) then
                  Clear_Status (Controller, Tx_Stream, Half_Transfer_Complete_Indicated);
               else -- not double buffered
                  if not Circular_Mode (Controller, Tx_Stream) then
                     Disable_Interrupt (Controller, Tx_Stream, Half_Transfer_Complete_Interrupt);
                  end if;
                  Clear_Status (Controller, Tx_Stream, Half_Transfer_Complete_Indicated);
               end if;
--                 Event_Kind := Half_Transfer_Complete_Interrupt;
--                 Event_Occurred := True;
            end if;
         end if;

         --  Transfer Complete Interrupt management
         if Status (Controller, Tx_Stream, Transfer_Complete_Indicated) then
            if Interrupt_Enabled (Controller, Tx_Stream, Transfer_Complete_Interrupt) then
                if Double_Buffered (Controller, Tx_Stream) then
                   Clear_Status (Controller, Tx_Stream, Transfer_Complete_Indicated);
                   --  TODO: handle the difference between M0 and M1 callbacks
                else
                   if not Circular_Mode (Controller, Tx_Stream) then
                      Disable_Interrupt (Controller, Tx_Stream, Transfer_Complete_Interrupt);
                   end if;
                  Clear_Status (Controller, Tx_Stream, Transfer_Complete_Indicated);
                end if;
               Finalize_DMA_Transmission (Transceiver);
               Event_Kind := Transfer_Complete_Interrupt;
               Event_Occurred := True;
            end if;
         end if;
      end IRQ_Handler;

   end Tx_IRQ_Handler;

   protected body Rx_IRQ_Handler is

      entry Await_Event (Occurrence : out USART_Interrupt)
        when Event_Occurred is
      begin
         Occurrence := Event_Kind;
         Event_Occurred := False;
      end Await_Event;

      procedure IRQ_Handler is
         Has_Suceed : Boolean;
      begin
         --  Received data interrupt management
         if Status (Transceiver, Read_Data_Register_Not_Empty) then
            Rx_Queue.Enqueue_Item
              (Half_Word_To_T_Uint8 (Current_Input (Transceiver) and 16#FF#),
               Has_Suceed);
            Clear_Status (Transceiver, Read_Data_Register_Not_Empty);
            Event_Kind := Received_Data_Not_Empty;
            Event_Occurred := True;
         end if;
      end IRQ_Handler;

   end Rx_IRQ_Handler;

end UART_Syslink;