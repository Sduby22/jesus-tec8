library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity control_unit is
    -- control_unit entity 定义
    port (
        -- pin 定义
        -- vector:
        SW : in std_logic_vector(2 downto 0); -- SWC SWB SWA, 控制台模式选择
        S: out std_logic_vector(3 downto 0); -- S3-S0, ALU运算类型选择
        IR: in std_logic_vector(7 downto 4); -- IR7-IR4, 指令操作码
        W: in std_logic_vector(3 downto 1); -- W(3)-W(1), 节拍电位
        SEL: out std_logic_vector(3 downto 0); -- SEL3-SEL0, SEL3-2:ALU-A, SEL1-0:ALU-B 

        T3: in std_logic; -- T3节拍脉冲
        CLR: in std_logic; -- 低电平有效
        SELCTL: out std_logic; -- 1:控制台操作 0:指令操作
        SBUS: out std_logic; -- 将开关数据送到DBUS
        -- ALU:
        C: in std_logic; -- 进位标志位
        Z: in std_logic; -- 零标志位
        LDC: out std_logic; -- 保存进位标志
        LDZ: out std_logic; -- 保存零标志
        CIN: out std_logic; -- 有进位
        M: out std_logic; -- 0:算术操作, 1:逻辑操作
        ABUS: out std_logic; -- 将ALU结果送到DBUS
        -- RAM:
        MBUS: out std_logic; -- 将内存左端口数据送到DBUS
        MEMW: out std_logic; -- 1:写存储器, 0:读存储器
        -- AR:
        LAR: out std_logic; -- 将DBUS上的数据打入AR
        ARINC: out std_logic; -- AR + 1
        -- PC:
        PCINC: out std_logic; -- PC + 1
        LPC: out std_logic; -- 将DBUS上的数据打入PC
        PCADD: out std_logic; -- PC + offset
        -- IR:
        LIR: out std_logic; -- 将从内存中取出的指令打入IR
        -- R0-R3:
        DRW: out std_logic; -- 将DBUS上的数据打入指定通用寄存器
        -- 时序发生器:
        STOP: out std_logic; -- 暂停信号
        SHORT: out std_logic; -- 使时序发生器不再产生W(2)
        LONG: out std_logic -- 使时序发生器产生W(3)
    );
end control_unit;

architecture arch of control_unit is
    -- 结构定义
    signal ST0: std_logic; -- ST0 代表控制台指令的不同周期. 详情见控制器流程图。
    signal SST0: std_logic; -- SST0: SET ST0 在机器周期末将ST0设置为1. 详情见控制器流程图。
    begin
        -- Q: 应该将哪些信号设置为敏感信号？
        -- A: 见实验报告
        process(W, CLR, SW, IR, C, Z, T3, ST0)
        begin
            -- 控制器核心逻辑
            -- 首先将所有输出信号初始化为0.
            SEL <= "0000";
            SELCTL <= '0';
            SBUS <= '0';
            LDC <= '0';
            LDZ <= '0';
            CIN <= '0';
            M <= '0';
            ABUS <= '0';
            MBUS <= '0';
            MEMW <= '0';
            LAR <= '0';
            ARINC <= '0';
            PCINC <= '0';
            LPC <= '0';
            PCADD <= '0';
            LIR <= '0';
            DRW <= '0';
            STOP <= '0';
            SHORT <= '0';
            LONG <= '0';
            SST0 <= '0';
            S <= "0000";

            -- 如果SST0被置位，则置位ST0
            -- 按下了CLR，应将SST0置1.
            if (CLR = '0') then
                ST0 <= '0';
            elsif (T3'event and T3 = '0') then
                if(SST0 = '1') then
                    ST0 <= '1';
                end if;
                if (ST0 = '1' AND W(2) = '1' AND SW = "100") then
                    ST0 <= '0';
                end if;
            end if;

            -- case SW语句：根据SWC-SWA进入相应的控制台指令
            case SW is
                when "100" =>
                    -- 写寄存器
                    SBUS <= '1';
                    SEL(3) <= ST0;
                    SEL(2) <= W(2);
                    SEL(1) <= NOT (W(2) XOR ST0);
                    SEL(0) <= W(1);
                    SELCTL <= '1';
                    DRW <= '1';
                    STOP <= '1';
                    SST0 <= W(2) AND NOT ST0;
                   
                when "011" =>
                    -- 读寄存器
                    SEL(3) <= W(2);
                    SEL(2) <= '0';
                    SEL(1) <= W(2);
                    SEL(0) <= '1';
                    SELCTL <= '1';
                    STOP <= '1';
                when "010" =>
                    -- 读存储器
                    SBUS <= NOT ST0;
                    LAR <= NOT ST0;
                    STOP <= '1';
                    SST0 <= NOT ST0;
                    SHORT <= '1';
                    SELCTL <= '1';
                    MBUS <= ST0;
                    ARINC <= ST0;
                when "001" =>
                    -- 写存储器
                    SBUS <= '1';
                    LAR <= NOT ST0;
                    STOP <= '1';
                    SST0 <= NOT ST0;
                    SHORT <= '1';
                    SELCTL <= '1';
                    MEMW <= ST0;
                    ARINC <= ST0;
                when "000" =>
                    -- 取指
                    if (ST0 = '0') then
                        -- 设置PC
                        SBUS <= '1';
                        LPC <= '1';
                        SHORT <= '1';
                        SST0 <='1';
                        STOP <= '1';
                    else 
                        -- W(1)取指、 W(2)/W(3) with LONG执行
                        LIR <= W(1);
                        PCINC <= W(1);
                        case IR is
                            when "0001" =>
                                -- ADD
                                if (W(2) = '1') then
                                    S <= "1001";
                                end if;
                                CIN <= W(2);
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                                LDC <= W(2);
                            when "0010" =>
                                -- SUB
                                if (W(2) = '1') then
                                    S <= "0110";
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                                LDC <= W(2);
                            when "0011" =>
                                -- AND
                                M <= W(2);-- 进行逻辑操作
                                if (W(2) = '1') then
                                    S <= "1011";
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                            when "0100" =>
                                -- INC
                                if (W(2) = '1') then
                                    S <= "0000";
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                                LDC <= W(2);
                            when "0101" =>
                                -- LD
                                if (W(2) = '1') then
                                    M <= '1';-- 进行逻辑操作
                                    S <= "1010";
                                    ABUS <= '1';
                                    LAR <= '1';
                                    LONG <= '1';
                                elsif (W(3) = '1') then
                                    DRW <= '1';
                                    MBUS <= '1';
                                end if;
                            when "0110" =>
                                -- ST
                                if (W(2) = '1') then
                                    M <= '1';-- 进行逻辑操作
                                    S <= "1111";
                                    ABUS <= '1';
                                    LAR <= '1';
                                    LONG <= '1';
                                elsif (W(3) = '1') then
                                    S <= "1010";
                                    M <= '1';-- 进行逻辑操作
                                    ABUS <= '1';
                                    MEMW <= '1';
                                end if;  
                            when "0111" =>
                                -- JC
                                if(C = '1') then
                                    PCADD <= W(2);
                                end if;
                            when "1000" =>
                                -- JZ
                                if(Z = '1') then
                                    PCADD <= W(2);
                                end if;
                            when "1001" =>
                                -- JMP
                                M <= W(2);-- 进行逻辑操作
                                if (W(2) = '1') then
                                    S <= "1111";
                                end if;
                                ABUS <= W(2);
                                LPC <= W(2);
                            when "1010" =>
                                -- MOV a,b (b -> a)
                                if (W(2) = '1') then
                                    S <= "1010";
                                    M <= '1';
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                            when "1011" =>
                                -- NEG a (!a -> a)
                                if (W(2) = '1') then
                                    S <= "0000";
                                    M <= '1';
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                            when "1100" =>
                                -- XOR a,b (a^b -> a)
                                if (W(2) = '1') then
                                    M <= '1';
                                    S <= "1001";
                                end if;
                                ABUS <= W(2);
                                DRW <= W(2);
                                LDZ <= W(2);
                            when "1101" =>
                                -- OUT a (a -> DBUS)
                                if (W(2) = '1') then
                                    S <= "1010"; -- 直通 B
                                    M <= '1';
                                end if;
                                ABUS <= W(2);
                            when "1110" =>
                                -- STP
                                STOP <= W(2);
                            -- TODO: 3条扩指
                            when others => null;
                        end case;
                    end if;
                when others => null;
            end case;
        end process;
end arch;
