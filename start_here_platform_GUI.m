function start_here_platform_GUI

% **********************************************************************************************************************
% This is the GUI for the IEEE 802.11ax Resource Management platform
% Author: Michael Knitter
% Runs with Matlab R2018b
% Needed Matlab toolboxes: WLAN-Toolbox V2.0 R2018b
% Needed Add-Ons: WINNER II Channel Model for Communication Toolbox
% Information: See folder documents
% Note about newer Matlab versions: Mathworks did a lot of changes with
% newer versions, which are not downwards compatible to this code. Two
% examples are changed helper functions and changes for table indexing.
% Therefore this code needs R2018b. Newer releases need code changes!
% **********************************************************************************************************************

% do some cleaning
close all;
clearvars;

PlatformVersion = ' - Version: 06 01/03/2022';

% create cell vector to hold all active bss
all_bss = cell(1,0);

% create cell vector to hold all active obstacles
all_obstacles = cell(1,0);

% create cell vector to hold all active path from each AP to each AP / STA
all_path_STA_DL = cell(1,1,1);
all_path_AP_DL = cell(1,1,1);

% create cell vector to hold all active path from each AP / STA to each AP / STA
all_path_STA_UL = cell(1,1,1,1);
all_path_AP_UL = cell(1,1,1,1);

% create cell vector to hold all pathlosses from each AP to each AP / STA
all_pathloss_STA_DL = cell(1,1,1);
all_pathloss_AP_DL = cell(1,1,1);

% create cell vector to hold all pathlosses from each AP / STA to each AP / STA
all_pathloss_STA_UL = cell(1,1,1,1);
all_pathloss_AP_UL = cell(1,1,1,1);

% create simulation structure to hold all simulation parameter
simulation.numPackets = 0;
simulation.interferer = 0;

% fixed parameters
simulation.CarrierFrequency = 2.4E9;

% use non-overlapping channels 1, 6, 11 as 1,2,3
simulation.numCH = 3;

% define default smallest cycle /s for data load model; overwritten by simulation.LoadCycle
simulation.DataQueueCycle = 0.010;

% define garbage selection parameter, every 10 ms clean of old channel
% max TXTIME from standard is 5.5 ms (table 28.50), save approach
simulation.GarbageCycle = 0.010;    
simulation.GarbageWindow = 0.010;    

% create cell vector to hold all simulation plots by User / BSS
resultU = cell(1,0);
resultB = cell(1,0);

% create structures for save & load of uicontrol elements
simu_var =[];
plot_var =[];

% **********************************************************************************************************************
% GUI START
% **********************************************************************************************************************

%  Create and hide GUI during construction
h_win = figure('Visible','off','Position',[0,0,1400,1000],'Units','normalized','Tag','GUIWindow');
h_win.Name = ['IEEE 802.11ax Resource Management' PlatformVersion];
h_win.NumberTitle = 'Off';
h_win.MenuBar = 'None';
h_win.ToolBar = 'None';

% **********************************************************************************************************************
% PANELS
% **********************************************************************************************************************

% **********************************************************************************************************************
% Construct panel and components for Add / Remove BSS selection
h_pan_bss = uipanel('Parent',h_win,'Title','BSS','FontSize',10,'Position',[.01 .8 0.985 .2],'Units','normalized');
      
h_bss_popup = uicontrol('Style','popupmenu','Parent',h_pan_bss,'String',{'9STA','4STA','2STA','1STA','Other'},...
    'Position',[40,160,100,20],'Units','normalized','Callback',@bss_type_popup_Callback);
  
h_add_bss_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_bss,'String',{'Add'},'FontSize',10,...
    'HorizontalAlignment','left','Position',[40,110,80,40],'Units','normalized','Callback',@add_bss_pushbtn_Callback);

h_bss_vec_popup = uicontrol('Style','popupmenu','Parent',h_pan_bss,'String',{''},'Position',[40,70,100,20],...
    'Units','normalized','Callback',@select_bss_pushbtn_Callback);

h_remove_bss_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_bss,'String',{'Remove'},'FontSize',10,...
    'HorizontalAlignment','left','Position',[40,20,80,40],'Units','normalized','Callback',@remove_bss_pushbtn_Callback);

h_mod_bss_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_bss,'String',{'Modify'},'FontSize',10,...
    'HorizontalAlignment','left','Position',[130,20,80,40],'Units','normalized','Callback',@modify_bss_pushbtn_Callback);

% **********************************************************************************************************************
% Construct panel and components for Add / Remove Obstacle selection
h_pan_obstacle = uipanel('Parent',h_win,'Title','Obstacle Plane','FontSize',10,'Position',...
    [.01 .72 0.985 .08],'Units','normalized');
      
h_add_obstacle_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_obstacle,'String',{'Add'},'FontSize',10,...
    'HorizontalAlignment','left','Position',[40,20,80,40],'Units','normalized','Callback',...
    @add_obstacle_pushbtn_Callback);
  
h_obstacle_vec_popup = uicontrol('Style','popupmenu','Parent',h_pan_obstacle,'String',{''},'Position',...
    [700,25,100,20],'Units','normalized','Callback',@select_obstacle_pushbtn_Callback);
  
h_remove_obstacle_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_obstacle,'String',{'Remove'},...
    'FontSize',10,'HorizontalAlignment','left','Position',[820,20,80,40],'Units','normalized',...
    'Callback',@remove_obstacle_pushbtn_Callback);

h_modify_obstacle_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_obstacle,'String',{'Modify'},...
    'FontSize',10,'HorizontalAlignment','left','Position',[910,20,80,40],'Units','normalized',...
    'Callback',@modify_obstacle_pushbtn_Callback);

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'Type'},'FontSize',8,'Position',[120,25,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'Point 1'},'FontSize',8,'Position',[330,40,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'Point 2'},'FontSize',8,'Position',[410,40,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'Point 3'},'FontSize',8,'Position',[490,40,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'Point 4'},'FontSize',8,'Position',[570,40,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_obstacle,...
   'String',{'[x y z]'},'FontSize',8,'Position',[270,25,50,20],'Units','normalized');

h_obstacle_popup = uicontrol('Style','popupmenu','Parent',h_pan_obstacle,'String',{'Wall','Floor'},...
    'Position',[170,25,70,20],'Units','normalized');
  
h_obstacle_pos1 = uicontrol('Style','edit','Parent',h_pan_obstacle,...
    'String',{'0 0 0'},'FontSize',8,'Position',[320,25,70,20],'Units','normalized');

h_obstacle_pos2 = uicontrol('Style','edit','Parent',h_pan_obstacle,...
    'String',{'0 20 0'},'FontSize',8,'Position',[400,25,70,20],'Units','normalized');

h_obstacle_pos3 = uicontrol('Style','edit','Parent',h_pan_obstacle,...
    'String',{'0 20 30'},'FontSize',8,'Position',[480,25,70,20],'Units','normalized');

h_obstacle_pos4 = uicontrol('Style','edit','Parent',h_pan_obstacle,...
    'String',{'0 0 30'},'FontSize',8,'Position',[560,25,70,20],'Units','normalized');

% **********************************************************************************************************************
% Construct panel and axes to display spatial config
h_pan_space = uipanel('Parent',h_win,'Title','Spatial Setup','FontSize',10,'Position',...
    [.01 .40 0.41 .32],'Units','normalized');
      
h_axes_space = axes('Parent',h_pan_space,'Position',[0.09,0.12,0.55,0.8]);

% add handle cell arrays to work on plotted APs, STAs and Obstacles
h_AP_space = {};
h_STA_space = {};
h_AP_ULA_space = {};
h_STA_ULA_space = {};
h_OB_space = {};

% path selection and display
uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'AP TX'},'FontSize',8,'Position',[400,260,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'STA TX'},'FontSize',8,'Position',[400,230,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'AP RX'},'FontSize',8,'Position',[400,200,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'STA RX'},'FontSize',8,'Position',[400,170,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'Distance'},'FontSize',8,'Position',[400,140,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'#Floors'},'FontSize',8,'Position',[400,110,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'#Walls'},'FontSize',8,'Position',[400,80,50,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_space,...
   'String',{'PL / dB'},'FontSize',8,'Position',[400,50,50,20],'Units','normalized');

h_path_ap_tx_popup = uicontrol('Style','popupmenu','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,260,100,20],'Units','normalized',...
   'Callback',@path_bss_tx_popup_Callback);

h_path_sta_tx_popup = uicontrol('Style','popupmenu','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,230,100,20],'Units','normalized',...
   'Callback',@path_sta_tx_popup_Callback);

h_path_ap_rx_popup = uicontrol('Style','popupmenu','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,200,100,20],'Units','normalized',...
   'Callback',@path_bss_rx_popup_Callback);

h_path_sta_rx_popup = uicontrol('Style','popupmenu','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,170,100,20],'Units','normalized',...
   'Callback',@path_sta_rx_popup_Callback);

h_path_distance = uicontrol('Style','edit','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,140,70,20],'Units','normalized');

h_path_floors = uicontrol('Style','edit','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,110,70,20],'Units','normalized');

h_path_walls = uicontrol('Style','edit','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,80,70,20],'Units','normalized');

h_path_PL = uicontrol('Style','edit','Parent',h_pan_space,...
   'String',{''},'FontSize',8,'Position',[460,50,70,20],'Units','normalized');

% **********************************************************************************************************************
% Construct panel for simulation
h_pan_simu = uipanel('Parent',h_win,'Title','Simulation','FontSize',10,'Position',...
    [.765 .01 0.23 .39],'Units','normalized');
        
h_simu_time = uicontrol('Style','text','Parent',h_pan_simu,'String',{'time'},'FontSize',12,'HorizontalAlignment',...
    'left','Position',[50,220,50,20],'Units','normalized');
  
h_simu_packets = uicontrol('Style','text','Parent',h_pan_simu,'String',{'packets'},...
      'FontSize',12,'HorizontalAlignment','left','Position',[50,190,50,20],'Units','normalized');
  
h_start_simu_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_simu,'String',{'Start'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[30,260,80,40],'Units','normalized',...
      'Callback',@start_simu_pushbtn_Callback);
  
% create flag to cancel GEQ loop through GUI
setappdata(h_start_simu_pushbtn,'cancelflag',0);
  
h_load_simu_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_simu,'String',{'Load Scen.'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[30,110,80,40],'Units','normalized',...
      'Callback',@load_simu_pushbtn_Callback);
  
h_save_simu_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_simu,'String',{'Save Scen.'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[30,50,80,40],'Units','normalized',...
      'Callback',@save_simu_pushbtn_Callback);
  
% simu time
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'SimuTime'},'FontSize',8,'Position',[35,330,70,20],'Units','normalized');
  
h_time = uicontrol('Style','edit','Parent',h_pan_simu,...
   'String',{'0.01'},'FontSize',8,'Position',[35,315,70,20],'Units','normalized');    

% phy selection
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'PHY Type'},'FontSize',8,'Position',[190,330,100,20],'Units','normalized');

h_PHY_type = uicontrol('Style','popupmenu','Parent',h_pan_simu,'String',{'IEEE 802.11ax',...
    'IEEE 802.11n','IEEE 802.11a'},'FontSize',8,'Position',[190,315,100,20],'Units','normalized');

% seed source selection
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'Seed Source'},'FontSize',8,'Position',[190,290,100,20],'Units','normalized');

h_RandomStream = uicontrol('Style','popupmenu','Parent',h_pan_simu,'String',{'Global stream',...
    'mt19937ar with seed'},'FontSize',8,'Position',[190,275,100,20],'Units','normalized');

% report level selection
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'Report Level'},'FontSize',8,'Position',[190,250,100,20],'Units','normalized');

h_ReportLevel = uicontrol('Style','popupmenu','Parent',h_pan_simu,'String',{'Basic',...
    'Standard','Extended'},'FontSize',8,'Position',[190,235,100,20],'Units','normalized','Value',2);

% min load cycle
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'MinLoadCycle'},'FontSize',8,'Position',[190,210,100,20],'Units','normalized');

h_LoadCycle = uicontrol('Style','edit','Parent',h_pan_simu,...
   'String',{'0.01'},'FontSize',8,'Position',[190,195,100,20],'Units','normalized'); 

% PER(SINR) curve offset
uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'PER(SINR)Offset'},'FontSize',8,'Position',[190,165,100,20],'Units','normalized');

h_PERSNROffset = uicontrol('Style','edit','Parent',h_pan_simu,...
   'String',{'0'},'FontSize',8,'Position',[190,150,95,20],'Units','normalized'); 

% User rate base along SNR

uicontrol('Style','text','Parent',h_pan_simu,...
   'String',{'R(SINR)Base'},'FontSize',8,'Position',[190,120,100,20],'Units','normalized');

h_RSNRBase = uicontrol('Style','popupmenu','Parent',h_pan_simu,'String',{'Sim1%PER',...
    'SimMAXTRP','IEEE802.11'},'FontSize',8,'Position',[190,105,100,20],'Units','normalized','Value',2);

% logging
h_DoLog = uicontrol('Style','checkbox','Parent',h_pan_simu,'Value',1,...
   'String','Logging','FontSize',8,'Position',[190,75,100,20],'Units','normalized');

% **********************************************************************************************************************
% Construct panel for channel and subpanels
h_pan_channel_par = uipanel('Parent',h_win,'Title','Channel Setup','FontSize',10,'Position',...
    [.425 .40 0.1 .32],'Units','normalized');

h_channel_popup = uicontrol('Style','popupmenu','Parent',h_pan_channel_par,'String',{'TGax','WINNER II','None'},...
    'Position',[10,280,100,20],'Units','normalized','Callback',@channel_model_popup_Callback);

% constant average power of channel
h_const_pow = uicontrol('Style','checkbox','Parent',h_pan_channel_par,'Value',0,...
   'String','Const Avg Pow','FontSize',8,'Position',[20,70,100,20],'Units','normalized');   

% use awgn
h_use_awgn = uicontrol('Style','checkbox','Parent',h_pan_channel_par,'Value',1,...
   'String','Add AWGN CH','FontSize',8,'Position',[20,20,100,20],'Units','normalized');   

% reset channel by packet
h_reset_stream = uicontrol('Style','checkbox','Parent',h_pan_channel_par,'Value',1,...
   'String','Reset CH / PCK','FontSize',8,'Position',[20,45,100,20],'Units','normalized');     

% **********************************************************************************************************************
% SUBPANEL TGax
h_pan_channel_tgax = uipanel('Parent',h_pan_channel_par,'Title','TGax',...
   'FontSize',8,'Position',[.02 .3 0.92 .6],'Units','normalized');   

% delay profile
uicontrol('Style','text','Parent',h_pan_channel_tgax,...
   'String',{'Delay Profile'},'FontSize',8,'Position',[10,145,100,20],'Units','normalized');

h_tgax_DelayProfile = uicontrol('Style','popupmenu','Parent',h_pan_channel_tgax,'String',{'Model-B','Model-A',...
    'Model-C','Model-D','Model-E','Model-F'},'FontSize',8,'Position',[10,130,100,20],'Units','normalized');   

% **********************************************************************************************************************
% SUBPANEL WINNER II
h_pan_channel_w2 = uipanel('Parent',h_pan_channel_par,'Title','WINNER II',...
   'FontSize',8,'Position',[.02 .3 0.92 .6],'Units','normalized');   

% scenario
uicontrol('Style','text','Parent',h_pan_channel_w2,...
   'String',{'Scenario'},'FontSize',8,'Position',[10,145,100,20],'Units','normalized');

h_w2_Scenario = uicontrol('Style','popupmenu','Parent',h_pan_channel_w2,'String',{'A1'},...
    'FontSize',8,'Position',[10,130,100,20],'Units','normalized');   

% propagation condition
uicontrol('Style','text','Parent',h_pan_channel_w2,...
   'String',{'Propagation'},'FontSize',8,'Position',[10,105,100,20],'Units','normalized');

h_w2_PropCondition = uicontrol('Style','popupmenu','Parent',h_pan_channel_w2,'String',{'NLOS','LOS'},...
    'FontSize',8,'Position',[10,90,100,20],'Units','normalized');   

% **********************************************************************************************************************
% Construct panel for pathloss type and subpanels
h_pan_pathloss_par = uipanel('Parent',h_win,'Title','Pathloss Model','FontSize',10,'Position',...
    [.53 .40 0.1 .32],'Units','normalized');
  
h_pathloss_popup = uicontrol('Style','popupmenu','Parent',h_pan_pathloss_par,'String',{'TGax','EtaPowerLaw','Other'},...
    'Position',[10,280,100,20],'Units','normalized','Callback',@pathloss_model_popup_Callback);

% **********************************************************************************************************************
% SUBPANEL TGax
h_pan_pathloss_tgax = uipanel('Parent',h_pan_pathloss_par,'Title','TGax',...
   'FontSize',8,'Position',[.02 .01 0.92 .9],'Units','normalized');   

% large scale fading effect
uicontrol('Style','text','Parent',h_pan_pathloss_tgax,...
   'String',{'LS Fading Effect'},'FontSize',8,'Position',[10,230,100,20],'Units','normalized');

h_LargeScaleFadingEffect_tgax = uicontrol('Style','popupmenu','Parent',h_pan_pathloss_tgax,'String',{'Pathloss',...
    'Shadowing','Pathloss and shadowing','None'},'FontSize',8,'Position',[10,215,100,20],'Units','normalized'...
    ,'Callback',@update_Pathloss_Callback);

% wall attenuation outside ax
uicontrol('Style','text','Parent',h_pan_pathloss_tgax,...
   'String',{'Wall Att / dB'},'FontSize',8,'Position',[10,185,100,20],'Units','normalized');

h_WallPenetrationLoss_tgax = uicontrol('Style','popupmenu','Parent',h_pan_pathloss_tgax,...
   'String',{'ax','5','10','15','20','25'},'FontSize',8,'Position',[10,170,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% **********************************************************************************************************************
% SUBPANEL eta power law
h_pan_pathloss_etapl = uipanel('Parent',h_pan_pathloss_par,'Title','Eta Power Law',...
   'FontSize',8,'Position',[.02 .01 0.92 .9],'Units','normalized');   

% breakpoint distance  dBP
uicontrol('Style','text','Parent',h_pan_pathloss_etapl,...
   'String',{'dBreakpoint / m'},'FontSize',8,'Position',[10,225,100,20],'Units','normalized');

h_BP_distance = uicontrol('Style','edit','Parent',h_pan_pathloss_etapl,...
   'String',{'5'},'FontSize',8,'Position',[10,210,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% eta for d <= dBP
uicontrol('Style','text','Parent',h_pan_pathloss_etapl,...
   'String',{'eta d <= dBP'},'FontSize',8,'Position',[10,185,100,20],'Units','normalized');

h_eta_bBP_distance = uicontrol('Style','edit','Parent',h_pan_pathloss_etapl,...
   'String',{'2'},'FontSize',8,'Position',[10,170,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% eta for d > dBP
uicontrol('Style','text','Parent',h_pan_pathloss_etapl,...
   'String',{'eta d > dBP'},'FontSize',8,'Position',[10,145,100,20],'Units','normalized');

h_eta_aBP_distance = uicontrol('Style','edit','Parent',h_pan_pathloss_etapl,...
   'String',{'3.5'},'FontSize',8,'Position',[10,130,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% wall attenuation
uicontrol('Style','text','Parent',h_pan_pathloss_etapl,...
   'String',{'Wall Att / dB'},'FontSize',8,'Position',[10,105,100,20],'Units','normalized');

h_WallPenetrationLoss = uicontrol('Style','edit','Parent',h_pan_pathloss_etapl,...
   'String',{'5'},'FontSize',8,'Position',[10,90,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% floor attenuation
uicontrol('Style','text','Parent',h_pan_pathloss_etapl,...
   'String',{'Floor Att / dB'},'FontSize',8,'Position',[10,65,100,20],'Units','normalized');

h_FloorPenetrationLoss = uicontrol('Style','edit','Parent',h_pan_pathloss_etapl,...
   'String',{'7'},'FontSize',8,'Position',[10,50,100,20],'Units','normalized'...
   ,'Callback',@update_Pathloss_Callback);

% **********************************************************************************************************************
% Construct panel for simulation type and subpanels
h_pan_simu_par = uipanel('Parent',h_win,'Title','Simulation Type','FontSize',10,'Position',...
    [.635 .4 0.36 .32],'Units','normalized');
      
h_simu_popup = uicontrol('Style','popupmenu','Parent',h_pan_simu_par,'String',{'CompareA2B','LoopOver'},...
    'Position',[10,280,100,20],'Units','normalized','Callback',@simu_type_popup_Callback);
            
h_simu_text = uicontrol('Style','text','Parent',h_pan_simu_par,'String',{'default explanation of simu type'},...
    'FontSize',10,'HorizontalAlignment','left','Position',[120,280,400,20],'Units','normalized');
  
% **********************************************************************************************************************
% SIMULATION PANELS
% **********************************************************************************************************************

% **********************************************************************************************************************
% Simu Panel COMPARE A2B
% construct 2 subpanels for A and B with parameters

% headings
h_pan_A2B = uipanel('Parent',h_pan_simu_par,'Title','COMPARE A2B',...
   'FontSize',8,'Position',[.01 .01 0.965 .9],'Units','normalized');

A2B_text = 'Compare 2 different resource management approaches';    

% A B selectors
h_A2B_popupA = uicontrol('Style','popupmenu','Parent',h_pan_A2B,'String',...
    {'CSMA/CA','CSMA/SR','CSMA/SDMSR'},'Value',1,...
  'Position',[10,235,100,20],'Units','normalized','Callback',@A2B_type_popupA_Callback);           
        
h_A2B_popupB = uicontrol('Style','popupmenu','Parent',h_pan_A2B,'String',...
    {'CSMA/CA','CSMA/SR','CSMA/SDMSR'},'Value',1,...
  'Position',[240,235,100,20],'Units','normalized','Callback',@A2B_type_popupB_Callback);
        
% **********************************************************************************************************************
% SUBPANEL A
% Type A1 = CSMA/CA
h_pan_A2B_A1 = uipanel('Parent',h_pan_A2B,'Title','CSMA/CA',...
   'FontSize',8,'Position',[.02 .05 0.46 .85],'Units','normalized');   

% dynamic rate control/selection DRC/DRS
h_A2B_A1_DRC = uicontrol('Style','checkbox','Parent',h_pan_A2B_A1,'Value',1,...
   'String','DynRateControl','FontSize',8,'Position',[10,180,100,20],'Units','normalized');  

% suppress interference
h_A2B_A1_NOINT = uicontrol('Style','checkbox','Parent',h_pan_A2B_A1,'Value',0,...
   'String','SuppressInterf.','FontSize',8,'Position',[10,155,100,20],'Units','normalized'); 

% use estimated SINR
h_A2B_A1_ESTSINR = uicontrol('Style','checkbox','Parent',h_pan_A2B_A1,'Value',0,...
   'String','UseEstSINR','FontSize',8,'Position',[10,130,100,20],'Units','normalized'); 

% use beamforming
h_A2B_A1_BEAMFORMING = uicontrol('Style','checkbox','Parent',h_pan_A2B_A1,'Value',0,...
   'String','UseBeamforming','FontSize',8,'Position',[10,105,100,20],'Units','normalized'); 

% **********************************************************************************************************************
% Type A8 = CSMA/SDMSR
h_pan_A2B_A8 = uipanel('Parent',h_pan_A2B,'Title','CSMA/SDMSR',...
   'FontSize',8,'Position',[.02 .05 0.46 .85],'Units','normalized');   

% popup for different CSMA/SDMSR version
uicontrol('Style','text','Parent',h_pan_A2B_A8,...
   'String',{'CSMA/SDMSR Version'},'FontSize',8,'Position',[10,180,120,20],'Units','normalized');

h_A2B_A8_VER = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A8,'String',{'CSMA/SDMSR V1'},...
    'Value',1,'Position',[10,165,120,20],'Units','normalized');  

% popup for different MCS alphabets
uicontrol('Style','text','Parent',h_pan_A2B_A8,...
   'String',{'MCSAlphabet'},'FontSize',8,'Position',[10,135,100,20],'Units','normalized');

h_A2B_A8_MA = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A8,'String',{'MCS_All','MCS_Med',...
    'MCS_Min'},'Value',1,'Position',[10,120,100,20],'Units','normalized');  

% popup for different allocation methodologies
uicontrol('Style','text','Parent',h_pan_A2B_A8,...
   'String',{'LeadAPAllocation'},'FontSize',8,'Position',[10,90,100,20],'Units','normalized');

h_A2B_A8_SchedAlloc = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A8,'String',{'maxLink','maxSystem','maxFairness'}...
    ,'Value',2,'Position',[10,75,100,20],'Units','normalized');

% **********************************************************************************************************************
% Type A9 = CSMA/SR
h_pan_A2B_A9 = uipanel('Parent',h_pan_A2B,'Title','CSMA/SR',...
   'FontSize',8,'Position',[.02 .05 0.46 .85],'Units','normalized');   

% popup for different CSMA/SR version
uicontrol('Style','text','Parent',h_pan_A2B_A9,...
   'String',{'CSMA/SR Version'},'FontSize',8,'Position',[10,180,120,20],'Units','normalized');

h_A2B_A9_VER = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A9,'String',{'CSMA/SR V1'},...
    'Value',1,'Position',[10,165,120,20],'Units','normalized');  

% popup for different MCS alphabets
uicontrol('Style','text','Parent',h_pan_A2B_A9,...
   'String',{'MCSAlphabet'},'FontSize',8,'Position',[10,135,100,20],'Units','normalized');

h_A2B_A9_MA = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A9,'String',{'MCS_All','MCS_Med',...
    'MCS_Min'},'Value',1,'Position',[10,120,100,20],'Units','normalized');  

% popup for different allocation methodologies
uicontrol('Style','text','Parent',h_pan_A2B_A9,...
   'String',{'LeadAPAllocation'},'FontSize',8,'Position',[10,90,100,20],'Units','normalized');

h_A2B_A9_SchedAlloc = uicontrol('Style','popupmenu','Parent',h_pan_A2B_A9,'String',{'maxLink','maxSystem','maxFairness'}...
    ,'Value',2,'Position',[10,75,100,20],'Units','normalized');

% **********************************************************************************************************************
% SUBPANEL B
% Type B1 = CSMA/CA
h_pan_A2B_B1 = uipanel('Parent',h_pan_A2B,'Title','CSMA/CA',...
   'FontSize',8,'Position',[.5 .05 0.46 .85],'Units','normalized');

% dynamic rate control/selection DRC/DRS
h_A2B_B1_DRC = uicontrol('Style','checkbox','Parent',h_pan_A2B_B1,'Value',1,...
   'String','DynRateControl','FontSize',8,'Position',[10,180,100,20],'Units','normalized');

% suppress interference
h_A2B_B1_NOINT = uicontrol('Style','checkbox','Parent',h_pan_A2B_B1,'Value',0,...
   'String','SuppressInterf.','FontSize',8,'Position',[10,155,100,20],'Units','normalized');

% use estimated SINR
h_A2B_B1_ESTSINR = uicontrol('Style','checkbox','Parent',h_pan_A2B_B1,'Value',0,...
   'String','UseEstSINR','FontSize',8,'Position',[10,130,100,20],'Units','normalized'); 

% use beamforming
h_A2B_B1_BEAMFORMING = uicontrol('Style','checkbox','Parent',h_pan_A2B_B1,'Value',0,...
   'String','UseBeamforming','FontSize',8,'Position',[10,105,100,20],'Units','normalized'); 

% **********************************************************************************************************************
% Type B8 = CSMA/SDMSR
h_pan_A2B_B8 = uipanel('Parent',h_pan_A2B,'Title','CSMA/SDMSR',...
   'FontSize',8,'Position',[.5 .05 0.46 .85],'Units','normalized');   

% popup for different CSMA/SDMSR version
uicontrol('Style','text','Parent',h_pan_A2B_B8,...
   'String',{'CSMA/SDMSR Version'},'FontSize',8,'Position',[10,180,120,20],'Units','normalized');

h_A2B_B8_VER = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B8,'String',{'CSMA/SDMSR V1'},...
    'Value',1,'Position',[10,165,120,20],'Units','normalized');  

% popup for different MCS alphabets
uicontrol('Style','text','Parent',h_pan_A2B_B8,...
   'String',{'MCSAlphabet'},'FontSize',8,'Position',[10,135,100,20],'Units','normalized');

h_A2B_B8_MA = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B8,'String',{'MCS_All','MCS_Med',...
    'MCS_Min'},'Value',1,'Position',[10,120,100,20],'Units','normalized');  

% popup for different allocation methodologies
uicontrol('Style','text','Parent',h_pan_A2B_B8,...
   'String',{'LeadAPAllocation'},'FontSize',8,'Position',[10,90,100,20],'Units','normalized');

h_A2B_B8_SchedAlloc = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B8,'String',{'maxLink','maxSystem','maxFairness'}...
    ,'Value',2,'Position',[10,75,100,20],'Units','normalized');

% **********************************************************************************************************************
% Type B9 = CSMA/SR
h_pan_A2B_B9 = uipanel('Parent',h_pan_A2B,'Title','CSMA/SDMSR',...
   'FontSize',8,'Position',[.5 .05 0.46 .85],'Units','normalized');   

% popup for different CSMA/SR version
uicontrol('Style','text','Parent',h_pan_A2B_B9,...
   'String',{'CSMA/SR Version'},'FontSize',8,'Position',[10,180,120,20],'Units','normalized');

h_A2B_B9_VER = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B9,'String',{'CSMA/SR V1'},...
    'Value',1,'Position',[10,165,120,20],'Units','normalized');  

% popup for different MCS alphabets
uicontrol('Style','text','Parent',h_pan_A2B_B9,...
   'String',{'MCSAlphabet'},'FontSize',8,'Position',[10,135,100,20],'Units','normalized');

h_A2B_B9_MA = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B9,'String',{'MCS_All','MCS_Med',...
    'MCS_Min'},'Value',1,'Position',[10,120,100,20],'Units','normalized');  

% popup for different allocation methodologies
uicontrol('Style','text','Parent',h_pan_A2B_B9,...
   'String',{'LeadAPAllocation'},'FontSize',8,'Position',[10,90,100,20],'Units','normalized');

h_A2B_B9_SchedAlloc = uicontrol('Style','popupmenu','Parent',h_pan_A2B_B9,'String',{'maxLink','maxSystem','maxFairness'}...
    ,'Value',2,'Position',[10,75,100,20],'Units','normalized');

% **********************************************************************************************************************
% Simu Panel LOOPOVER    
% headings
h_pan_LOOP = uipanel('Parent',h_pan_simu_par,'Title','LOOP OVER PARAMETER',...
   'FontSize',8,'Position',[.01 .01 0.965 .9],'Units','normalized');

LOOP_text = 'CSMA/CA loop over single parameter';    

% parameter selector
h_LOOP_popup = uicontrol('Style','popupmenu','Parent',h_pan_LOOP,'String',{'PayloadLength','MCS','TransmitPower',...
    'OBSS_PDLevel','SNR'},'Position',[10,230,100,20],'Units','normalized');  

uicontrol('Style','text','Parent',h_pan_LOOP,...
'String',{'OBSS_PD: Start:Step:Stop'},'FontSize',8,'Position',[150,150,170,20],'Units','normalized');

h_LOOP_OBSSPD = uicontrol('Style','edit','Parent',h_pan_LOOP,...
'String',{'-82:10:-62'},'FontSize',8,'Position',[330,150,100,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_LOOP,...
'String',{'SNR: Start:Step:Stop'},'FontSize',8,'Position',[150,125,170,20],'Units','normalized');

h_LOOP_SNR = uicontrol('Style','edit','Parent',h_pan_LOOP,...
'String',{'0:5:40'},'FontSize',8,'Position',[330,125,100,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_LOOP,...
'String',{'TP: Start:Step:Stop'},'FontSize',8,'Position',[150,175,170,20],'Units','normalized');

h_LOOP_TP = uicontrol('Style','edit','Parent',h_pan_LOOP,...
'String',{'-20:10:20'},'FontSize',8,'Position',[330,175,100,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_LOOP,...
'String',{'MCS: Start:Step:Stop'},'FontSize',8,'Position',[150,200,170,20],'Units','normalized');

h_LOOP_MCS = uicontrol('Style','edit','Parent',h_pan_LOOP,...
'String',{'0:1:11'},'FontSize',8,'Position',[330,200,100,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_LOOP,...
'String',{'Payload / STS: Start:Step:Stop'},'FontSize',8,'Position',[150,225,170,20],'Units','normalized');

h_LOOP_PLLength = uicontrol('Style','edit','Parent',h_pan_LOOP,...
'String',{'1000:500:2500'},'FontSize',8,'Position',[330,225,100,20],'Units','normalized');     

% dynamic rate control/selection DRC/DRS
h_LOOP_DRC = uicontrol('Style','checkbox','Parent',h_pan_LOOP,'Value',1,...
   'String','DynRateControl','FontSize',8,'Position',[10,110,100,20],'Units','normalized');    

% suppress interference
h_LOOP_NOINT = uicontrol('Style','checkbox','Parent',h_pan_LOOP,'Value',0,...
   'String','SuppressInterf.','FontSize',8,'Position',[10,85,100,20],'Units','normalized');    

% adjust TP along OBSS_PD
h_LOOP_TPOBSSPD = uicontrol('Style','checkbox','Parent',h_pan_LOOP,'Value',1,...
   'String','TPbyOBSS_PD','FontSize',8,'Position',[10,60,100,20],'Units','normalized');  

% use estimated SINR
h_LOOP_ESTSINR = uicontrol('Style','checkbox','Parent',h_pan_LOOP,'Value',1,...
   'String','UseESTSINR','FontSize',8,'Position',[10,35,100,20],'Units','normalized');  

% use beamforming
h_LOOP_BEAMFORMING = uicontrol('Style','checkbox','Parent',h_pan_LOOP,'Value',0,...
   'String','UseBeamforming','FontSize',8,'Position',[10,10,100,20],'Units','normalized');  

% **********************************************************************************************************************
% RESULT PLOT PANEL
% **********************************************************************************************************************

% **********************************************************************************************************************
h_pan_plot = uipanel('Parent',h_win,'Title','Plots',...
   'FontSize',10,'Position',[.01 .01 0.75 .39],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'Target BSS'},'FontSize',8,'Position',[35,350,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'BSS Report'},'FontSize',8,'Position',[35,310,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'System Report'},'FontSize',8,'Position',[225,350,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'Target BSS'},'FontSize',8,'Position',[630,350,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'BSS Report'},'FontSize',8,'Position',[630,310,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_plot,...
   'String',{'System Report'},'FontSize',8,'Position',[820,350,70,20],'Units','normalized');

h_plot_BSS_left = uicontrol('Style','popupmenu','Parent',h_pan_plot,...
   'String',{''},'FontSize',8,'Position',[105,350,100,20],'Units','normalized',...
   'Callback',@select_bss_plot_left_Callback);

h_plot_BSS_right = uicontrol('Style','popupmenu','Parent',h_pan_plot,'String',{''},'FontSize',8,'Position',...
    [700,350,100,20],'Units','normalized','Callback',@select_bss_plot_right_Callback);

h_plot_AP_left = uicontrol('Style','popupmenu','Parent',h_pan_plot,'String',{''},'FontSize',8,'Position',...
    [305,350,100,20],'Units','normalized','Callback',@select_AP_plot_left_Callback);

h_plot_AP_right = uicontrol('Style','popupmenu','Parent',h_pan_plot,'String',{''},'FontSize',8,'Position',...
    [900,350,100,20],'Units','normalized','Callback',@select_AP_plot_right_Callback);

h_plot_left = uicontrol('Style','popupmenu','Parent',h_pan_plot,'String',{''},'FontSize',8,'Position',...
    [105,310,300,20],'Units','normalized','Callback',@select_plot_left_Callback);

h_plot_right = uicontrol('Style','popupmenu','Parent',h_pan_plot,'String',{''},'FontSize',8,'Position',...
    [700,310,300,20],'Units','normalized','Callback',@select_plot_right_Callback);   

h_load_plot_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_plot,'String',{'Load Rep.'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[480,310,80,40],'Units','normalized',...
      'Callback',@load_plot_pushbtn_Callback);
  
h_save_plot_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_plot,'String',{'Save Rep.'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[480,250,80,40],'Units','normalized',...
      'Callback',@save_plot_pushbtn_Callback);      
  
h_push_fig_pushbtn = uicontrol('Style','pushbutton','Parent',h_pan_plot,'String',{'Push Fig.'},...
      'FontSize',10,'HorizontalAlignment','left','Position',[480,190,80,40],'Units','normalized',...
      'Callback',@push_fig_pushbtn_Callback);      
  
pos_plot_left = [0.06,0.12,0.33,0.63];
pos_plot_right = [0.63,0.12,0.33,0.63];

h_axes_plot_left = axes('Parent',h_pan_plot,'Position',pos_plot_left);
h_axes_plot_right = axes('Parent',h_pan_plot,'Position',pos_plot_right);

% **********************************************************************************************************************
% BSS PANELS
% **********************************************************************************************************************

% **********************************************************************************************************************
% BSS Panel 9STA
% headings
h_pan_9STA = uipanel('Parent',h_pan_bss,'Title','9STA',...
   'FontSize',8,'Position',[.22 .04 0.77 .95],'Units','normalized');

% T9STA_text = 'AP to 9 STA';

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'AP'},'FontSize',8,'Position',[100,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA1'},'FontSize',8,'Position',[250,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA2'},'FontSize',8,'Position',[330,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA3'},'FontSize',8,'Position',[410,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA4'},'FontSize',8,'Position',[490,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA5'},'FontSize',8,'Position',[570,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA6'},'FontSize',8,'Position',[650,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA7'},'FontSize',8,'Position',[730,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA8'},'FontSize',8,'Position',[810,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'STA9'},'FontSize',8,'Position',[890,145,30,20],'Units','normalized');

% positions
uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[0,130,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[160,130,70,20],'Units','normalized');

h_9STA_AP_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'5 10 10'},'FontSize',8,'Position',[80,130,70,20],'Units','normalized');

h_9STA_STA1_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'10 10 10'},'FontSize',8,'Position',[230,130,70,20],'Units','normalized');

h_9STA_STA2_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'20 10 10'},'FontSize',8,'Position',[310,130,70,20],'Units','normalized');

h_9STA_STA3_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'30 10 10'},'FontSize',8,'Position',[390,130,70,20],'Units','normalized');

h_9STA_STA4_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'40 10 10'},'FontSize',8,'Position',[470,130,70,20],'Units','normalized');

h_9STA_STA5_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'50 10 10'},'FontSize',8,'Position',[550,130,70,20],'Units','normalized');

h_9STA_STA6_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'60 10 10'},'FontSize',8,'Position',[630,130,70,20],'Units','normalized');

h_9STA_STA7_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'70 10 10'},'FontSize',8,'Position',[710,130,70,20],'Units','normalized');

h_9STA_STA8_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'80 10 10'},'FontSize',8,'Position',[790,130,70,20],'Units','normalized');

h_9STA_STA9_pos = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'90 10 10'},'FontSize',8,'Position',[870,130,70,20],'Units','normalized');

% MCSs
mcs_vec = {'MCS0','MCS1','MCS2','MCS3','MCS4','MCS5','MCS6','MCS7','MCS8','MCS9','MCS10','MCS11'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'MCS'},'FontSize',8,'Position',[160,100,70,20],'Units','normalized');

h_9STA_STA1_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[230,100,70,20],'Units','normalized','Value',6);

h_9STA_STA2_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[310,100,70,20],'Units','normalized','Value',6);

h_9STA_STA3_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[390,100,70,20],'Units','normalized','Value',6);

h_9STA_STA4_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[470,100,70,20],'Units','normalized','Value',6);

h_9STA_STA5_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[550,100,70,20],'Units','normalized','Value',6);

h_9STA_STA6_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[630,100,70,20],'Units','normalized','Value',6);

h_9STA_STA7_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[710,100,70,20],'Units','normalized','Value',6);

h_9STA_STA8_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[790,100,70,20],'Units','normalized','Value',6);

h_9STA_STA9_mcs = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',mcs_vec,'FontSize',8,'Position',[870,100,70,20],'Units','normalized','Value',6);   

% APEP_Length
uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'Payload / STS'},'FontSize',8,'Position',[160,70,70,20],'Units','normalized');

h_9STA_STA1_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[230,70,70,20],'Units','normalized');

h_9STA_STA2_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[310,70,70,20],'Units','normalized');

h_9STA_STA3_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[390,70,70,20],'Units','normalized');

h_9STA_STA4_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[470,70,70,20],'Units','normalized');

h_9STA_STA5_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[550,70,70,20],'Units','normalized');

h_9STA_STA6_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[630,70,70,20],'Units','normalized');

h_9STA_STA7_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[710,70,70,20],'Units','normalized');

h_9STA_STA8_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[790,70,70,20],'Units','normalized');

h_9STA_STA9_apep = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String','1500','FontSize',8,'Position',[870,70,70,20],'Units','normalized');

% #STSs
sts_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'#STS'},'FontSize',8,'Position',[160,40,70,20],'Units','normalized');

h_9STA_STA1_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[230,40,70,20],'Units','normalized');

h_9STA_STA2_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[310,40,70,20],'Units','normalized');

h_9STA_STA3_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[390,40,70,20],'Units','normalized');

h_9STA_STA4_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[470,40,70,20],'Units','normalized');

h_9STA_STA5_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[550,40,70,20],'Units','normalized');

h_9STA_STA6_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[630,40,70,20],'Units','normalized');

h_9STA_STA7_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[710,40,70,20],'Units','normalized');

h_9STA_STA8_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[790,40,70,20],'Units','normalized');

h_9STA_STA9_sts = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',sts_vec,'FontSize',8,'Position',[870,40,70,20],'Units','normalized'); 

% #Loads
load_vec = {'St1Mbs','St5Mbs','St10Mbs','St100Mbs','St500Mbs','St1000Mbs','Pk1Mbs','Pk5Mbs','Pk10Mbs','Lt80b100kbs','Lt8kb1Mbs','Lt8kb10Mbs','Lt8kb100Mbs','PkRandom'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'Load-Mod'},'FontSize',8,'Position',[160,10,70,20],'Units','normalized');

h_9STA_STA1_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[230,10,70,20],'Units','normalized','Value',4);

h_9STA_STA2_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[310,10,70,20],'Units','normalized','Value',4);

h_9STA_STA3_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[390,10,70,20],'Units','normalized','Value',4);

h_9STA_STA4_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[470,10,70,20],'Units','normalized','Value',4);

h_9STA_STA5_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[550,10,70,20],'Units','normalized','Value',4);

h_9STA_STA6_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[630,10,70,20],'Units','normalized','Value',4);

h_9STA_STA7_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[710,10,70,20],'Units','normalized','Value',4);

h_9STA_STA8_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[790,10,70,20],'Units','normalized','Value',4);

h_9STA_STA9_load = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',load_vec,'FontSize',8,'Position',[870,10,70,20],'Units','normalized','Value',4); 

% #TX RX
rxtx_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'#ANT TX RX'},'FontSize',8,'Position',[0,70,70,20],'Units','normalized');

h_9STA_num_tx = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[80,70,33,20],'Units','normalized');

h_9STA_num_rx = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[115,70,33,20],'Units','normalized');

% BSS color
cc_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'BSS CC'},'FontSize',8,'Position',[0,40,70,20],'Units','normalized');

h_9STA_bss_cc = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',cc_vec,'FontSize',8,'Position',[80,40,33,20],'Units','normalized');

% TX Power
uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'TX-Pwr / dBm'},'FontSize',8,'Position',[0,10,70,20],'Units','normalized');

h_9STA_tx_power = uicontrol('Style','edit','Parent',h_pan_9STA,...
   'String',{'20'},'FontSize',8,'Position',[80,10,70,20],'Units','normalized');

% Channel
ch_vec = {'CH 1','CH 6','CH 11'};

uicontrol('Style','text','Parent',h_pan_9STA,...
   'String',{'Channel'},'FontSize',8,'Position',[0,100,70,20],'Units','normalized');

h_9STA_ch = uicontrol('Style','popupmenu','Parent',h_pan_9STA,...
   'String',ch_vec,'FontSize',8,'Position',[80,100,70,20],'Units','normalized','Value',1);

% **********************************************************************************************************************
% BSS Panel 4STA
% headings
h_pan_4STA = uipanel('Parent',h_pan_bss,'Title','4STA',...
   'FontSize',8,'Position',[.22 .04 0.77 .95],'Units','normalized');
% T4STA_text = 'AP to 4 STA';

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'AP'},'FontSize',8,'Position',[100,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'STA1'},'FontSize',8,'Position',[250,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'STA2'},'FontSize',8,'Position',[330,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'STA3'},'FontSize',8,'Position',[410,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'STA4'},'FontSize',8,'Position',[490,145,30,20],'Units','normalized');

% positions
uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[0,130,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[160,130,70,20],'Units','normalized');

h_4STA_AP_pos = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'5 5 5'},'FontSize',8,'Position',[80,130,70,20],'Units','normalized');

h_4STA_STA1_pos = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'10 5 5'},'FontSize',8,'Position',[230,130,70,20],'Units','normalized');

h_4STA_STA2_pos = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'20 5 5'},'FontSize',8,'Position',[310,130,70,20],'Units','normalized');

h_4STA_STA3_pos = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'30 5 5'},'FontSize',8,'Position',[390,130,70,20],'Units','normalized');

h_4STA_STA4_pos = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'40 5 5'},'FontSize',8,'Position',[470,130,70,20],'Units','normalized');

% MCSs
mcs_vec = {'MCS0','MCS1','MCS2','MCS3','MCS4','MCS5','MCS6','MCS7','MCS8','MCS9','MCS10','MCS11'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'MCS'},'FontSize',8,'Position',[160,100,70,20],'Units','normalized');

h_4STA_STA1_mcs = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',mcs_vec,'FontSize',8,'Position',[230,100,70,20],'Units','normalized','Value',6);

h_4STA_STA2_mcs = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',mcs_vec,'FontSize',8,'Position',[310,100,70,20],'Units','normalized','Value',6);

h_4STA_STA3_mcs = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',mcs_vec,'FontSize',8,'Position',[390,100,70,20],'Units','normalized','Value',6);

h_4STA_STA4_mcs = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',mcs_vec,'FontSize',8,'Position',[470,100,70,20],'Units','normalized','Value',6);

% APEP_Length
uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'Payload / STS'},'FontSize',8,'Position',[160,70,70,20],'Units','normalized');

h_4STA_STA1_apep = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String','1500','FontSize',8,'Position',[230,70,70,20],'Units','normalized');

h_4STA_STA2_apep = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String','1500','FontSize',8,'Position',[310,70,70,20],'Units','normalized');

h_4STA_STA3_apep = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String','1500','FontSize',8,'Position',[390,70,70,20],'Units','normalized');

h_4STA_STA4_apep = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String','1500','FontSize',8,'Position',[470,70,70,20],'Units','normalized');

% #STSs
sts_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'#STS'},'FontSize',8,'Position',[160,40,70,20],'Units','normalized');

h_4STA_STA1_sts = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',sts_vec,'FontSize',8,'Position',[230,40,70,20],'Units','normalized');

h_4STA_STA2_sts = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',sts_vec,'FontSize',8,'Position',[310,40,70,20],'Units','normalized');

h_4STA_STA3_sts = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',sts_vec,'FontSize',8,'Position',[390,40,70,20],'Units','normalized');

h_4STA_STA4_sts = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',sts_vec,'FontSize',8,'Position',[470,40,70,20],'Units','normalized');

% #Loads
load_vec = {'St1Mbs','St5Mbs','St10Mbs','St100Mbs','St500Mbs','St1000Mbs','Pk1Mbs','Pk5Mbs','Pk10Mbs','Lt80b100kbs','Lt8kb1Mbs','Lt8kb10Mbs','Lt8kb100Mbs','PkRandom'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'Load-Mod'},'FontSize',8,'Position',[160,10,70,20],'Units','normalized');

h_4STA_STA1_load = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',load_vec,'FontSize',8,'Position',[230,10,70,20],'Units','normalized','Value',4);

h_4STA_STA2_load = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',load_vec,'FontSize',8,'Position',[310,10,70,20],'Units','normalized','Value',4);

h_4STA_STA3_load = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',load_vec,'FontSize',8,'Position',[390,10,70,20],'Units','normalized','Value',4);

h_4STA_STA4_load = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',load_vec,'FontSize',8,'Position',[470,10,70,20],'Units','normalized','Value',4);

% #TX RX
rxtx_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'#ANT TX RX'},'FontSize',8,'Position',[0,70,70,20],'Units','normalized');

h_4STA_num_tx = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[80,70,33,20],'Units','normalized');

h_4STA_num_rx = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[115,70,33,20],'Units','normalized');

% BSS color
cc_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'BSS CC'},'FontSize',8,'Position',[0,40,70,20],'Units','normalized');

h_4STA_bss_cc = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',cc_vec,'FontSize',8,'Position',[80,40,33,20],'Units','normalized');

   % TX Power
uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'TX-Pwr / dBm'},'FontSize',8,'Position',[0,10,70,20],'Units','normalized');

h_4STA_tx_power = uicontrol('Style','edit','Parent',h_pan_4STA,...
   'String',{'20'},'FontSize',8,'Position',[80,10,70,20],'Units','normalized');

% Channel
ch_vec = {'CH 1','CH 6','CH 11'};

uicontrol('Style','text','Parent',h_pan_4STA,...
   'String',{'Channel'},'FontSize',8,'Position',[0,100,70,20],'Units','normalized');

h_4STA_ch = uicontrol('Style','popupmenu','Parent',h_pan_4STA,...
   'String',ch_vec,'FontSize',8,'Position',[80,100,70,20],'Units','normalized','Value',1);

% **********************************************************************************************************************
% BSS Panel 2STA
% headings
h_pan_2STA = uipanel('Parent',h_pan_bss,'Title','2STA',...
   'FontSize',8,'Position',[.22 .04 0.77 .95],'Units','normalized');

% T2STA_text = 'AP to 2 STA';

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'AP'},'FontSize',8,'Position',[100,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'STA1'},'FontSize',8,'Position',[250,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'STA2'},'FontSize',8,'Position',[330,145,30,20],'Units','normalized');

% positions
uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[0,130,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[160,130,70,20],'Units','normalized');

h_2STA_AP_pos = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String',{'5 5 5'},'FontSize',8,'Position',[80,130,70,20],'Units','normalized');

h_2STA_STA1_pos = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String',{'10 5 5'},'FontSize',8,'Position',[230,130,70,20],'Units','normalized');

h_2STA_STA2_pos = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String',{'20 5 5'},'FontSize',8,'Position',[310,130,70,20],'Units','normalized');

% MCSs
mcs_vec = {'MCS0','MCS1','MCS2','MCS3','MCS4','MCS5','MCS6','MCS7','MCS8','MCS9','MCS10','MCS11'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'MCS'},'FontSize',8,'Position',[160,100,70,20],'Units','normalized');

h_2STA_STA1_mcs = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',mcs_vec,'FontSize',8,'Position',[230,100,70,20],'Units','normalized','Value',6);

h_2STA_STA2_mcs = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',mcs_vec,'FontSize',8,'Position',[310,100,70,20],'Units','normalized','Value',6);

% APEP_Length
uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'Payload / STS'},'FontSize',8,'Position',[160,70,70,20],'Units','normalized');

h_2STA_STA1_apep = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String','1500','FontSize',8,'Position',[230,70,70,20],'Units','normalized');

h_2STA_STA2_apep = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String','1500','FontSize',8,'Position',[310,70,70,20],'Units','normalized');

% #STSs
sts_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'#STS'},'FontSize',8,'Position',[160,40,70,20],'Units','normalized');

h_2STA_STA1_sts = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',sts_vec,'FontSize',8,'Position',[230,40,70,20],'Units','normalized');

h_2STA_STA2_sts = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',sts_vec,'FontSize',8,'Position',[310,40,70,20],'Units','normalized');

% #Loads
load_vec = {'St1Mbs','St5Mbs','St10Mbs','St100Mbs','St500Mbs','St1000Mbs','Pk1Mbs','Pk5Mbs','Pk10Mbs','Lt80b100kbs','Lt8kb1Mbs','Lt8kb10Mbs','Lt8kb100Mbs','PkRandom'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'Load-Mod'},'FontSize',8,'Position',[160,10,70,20],'Units','normalized');

h_2STA_STA1_load = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',load_vec,'FontSize',8,'Position',[230,10,70,20],'Units','normalized','Value',4);

h_2STA_STA2_load = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',load_vec,'FontSize',8,'Position',[310,10,70,20],'Units','normalized','Value',4);

% #TX RX
rxtx_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'#ANT TX RX'},'FontSize',8,'Position',[0,70,70,20],'Units','normalized');

h_2STA_num_tx = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[80,70,33,20],'Units','normalized');

h_2STA_num_rx = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[115,70,33,20],'Units','normalized');

% BSS color
cc_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'BSS CC'},'FontSize',8,'Position',[0,40,70,20],'Units','normalized');

h_2STA_bss_cc = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',cc_vec,'FontSize',8,'Position',[80,40,33,20],'Units','normalized');

% TX Power
uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'TX-Pwr / dBm'},'FontSize',8,'Position',[0,10,70,20],'Units','normalized');

h_2STA_tx_power = uicontrol('Style','edit','Parent',h_pan_2STA,...
   'String',{'20'},'FontSize',8,'Position',[80,10,70,20],'Units','normalized');

% Channel
ch_vec = {'CH 1','CH 6','CH 11'};

uicontrol('Style','text','Parent',h_pan_2STA,...
   'String',{'Channel'},'FontSize',8,'Position',[0,100,70,20],'Units','normalized');

h_2STA_ch = uicontrol('Style','popupmenu','Parent',h_pan_2STA,...
   'String',ch_vec,'FontSize',8,'Position',[80,100,70,20],'Units','normalized','Value',1);

% **********************************************************************************************************************
% BSS Panel 1STA
% headings
h_pan_1STA = uipanel('Parent',h_pan_bss,'Title','1STA',...
   'FontSize',8,'Position',[.22 .04 0.77 .95],'Units','normalized');

% T1STA_text = 'AP to 1 STA';

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'AP'},'FontSize',8,'Position',[100,145,30,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'STA1'},'FontSize',8,'Position',[250,145,30,20],'Units','normalized');

% positions
uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[0,130,70,20],'Units','normalized');

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'Position [x y z]'},'FontSize',8,'Position',[160,130,70,20],'Units','normalized');

h_1STA_AP_pos = uicontrol('Style','edit','Parent',h_pan_1STA,...
   'String',{'5 5 5'},'FontSize',8,'Position',[80,130,70,20],'Units','normalized');

h_1STA_STA1_pos = uicontrol('Style','edit','Parent',h_pan_1STA,...
   'String',{'10 5 5'},'FontSize',8,'Position',[230,130,70,20],'Units','normalized');

% MCSs
mcs_vec = {'MCS0','MCS1','MCS2','MCS3','MCS4','MCS5','MCS6','MCS7','MCS8','MCS9','MCS10','MCS11'};

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'MCS'},'FontSize',8,'Position',[160,100,70,20],'Units','normalized');

h_1STA_STA1_mcs = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',mcs_vec,'FontSize',8,'Position',[230,100,70,20],'Units','normalized','Value',6);

% APEP_Length
uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'Payload / STS'},'FontSize',8,'Position',[160,70,70,20],'Units','normalized');

h_1STA_STA1_apep = uicontrol('Style','edit','Parent',h_pan_1STA,...
   'String','1500','FontSize',8,'Position',[230,70,70,20],'Units','normalized');

% #STSs
sts_vec = {'1','2','3','4','5','6','7','8'};
uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'#STS'},'FontSize',8,'Position',[160,40,70,20],'Units','normalized');

h_1STA_STA1_sts = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',sts_vec,'FontSize',8,'Position',[230,40,70,20],'Units','normalized');

  % #Loads
load_vec = {'St1Mbs','St5Mbs','St10Mbs','St100Mbs','St500Mbs','St1000Mbs','Pk1Mbs','Pk5Mbs','Pk10Mbs','Lt80b100kbs','Lt8kb1Mbs','Lt8kb10Mbs','Lt8kb100Mbs','PkRandom'};

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'Load-Mod'},'FontSize',8,'Position',[160,10,70,20],'Units','normalized');

h_1STA_STA1_load = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',load_vec,'FontSize',8,'Position',[230,10,70,20],'Units','normalized','Value',4);

% #TX RX
rxtx_vec = {'1','2','3','4','5','6','7','8'};

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'#ANT TX RX'},'FontSize',8,'Position',[0,70,70,20],'Units','normalized');

h_1STA_num_tx = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[80,70,33,20],'Units','normalized');

h_1STA_num_rx = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',rxtx_vec,'FontSize',8,'Position',[115,70,33,20],'Units','normalized');

% BSS color
cc_vec = {'1','2','3','4','5','6','7','8'};
uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'BSS CC'},'FontSize',8,'Position',[0,40,70,20],'Units','normalized');

h_1STA_bss_cc = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',cc_vec,'FontSize',8,'Position',[80,40,33,20],'Units','normalized');

% TX Power
uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'TX-Pwr / dBm'},'FontSize',8,'Position',[0,10,70,20],'Units','normalized');

h_1STA_tx_power = uicontrol('Style','edit','Parent',h_pan_1STA,...
   'String',{'20'},'FontSize',8,'Position',[80,10,70,20],'Units','normalized');

% Channel
ch_vec = {'CH 1','CH 6','CH 11'};

uicontrol('Style','text','Parent',h_pan_1STA,...
   'String',{'Channel'},'FontSize',8,'Position',[0,100,70,20],'Units','normalized');

h_1STA_ch = uicontrol('Style','popupmenu','Parent',h_pan_1STA,...
   'String',ch_vec,'FontSize',8,'Position',[80,100,70,20],'Units','normalized','Value',1);

% **********************************************************************************************************************
% INIT GUI
% **********************************************************************************************************************

% **********************************************************************************************************************
% Initialize to meaningful default values for menu selections

% BSS
h_bss_popup.Value = 1;
% h_bss_text.String = T9STA_text;
bss_type_popup_Callback(h_bss_popup,'')

% Simulation Type
h_simu_popup.Value = 1;
h_simu_text.String = A2B_text;
simu_type_popup_Callback(h_simu_popup,'')

%Pathloss Model (incl. pathloss calculation)
h_pathloss_popup.Value = 1;
pathloss_model_popup_Callback(h_pathloss_popup,'')

%Fading Channel Model
h_channel_popup.Value = 1;
channel_model_popup_Callback(h_channel_popup,'')

% **********************************************************************************************************************
% Move the GUI to the center of the screen.
movegui(h_win,'center')

% Make the GUI visible.
h_win.Visible = 'on';

% **********************************************************************************************************************
% CALLBACKS
% **********************************************************************************************************************

% **********************************************************************************************************************
%  Pop-up menu callback BSS TYPE
function bss_type_popup_Callback(source,eventdata) 
    % switch off all bss panels
    h_pan_9STA.Visible = 'off';
    h_pan_4STA.Visible = 'off';
    h_pan_2STA.Visible = 'off';
    h_pan_1STA.Visible = 'off';

    % Determine the selected BSS type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
    case '9STA'
        h_pan_9STA.Visible = 'on';
    case '4STA'
        h_pan_4STA.Visible = 'on';
    case '2STA'
        h_pan_2STA.Visible = 'on';
    case '1STA'
        h_pan_1STA.Visible = 'on';
    case 'Other'
        % do nothing right now
    end
end   
% **********************************************************************************************************************
% Push button callback ADD BSS 
function add_bss_pushbtn_Callback(source,eventdata) 
    
    % Determine the selected bss type
    str = h_bss_popup.String;
    val = h_bss_popup.Value;
    
    % Load variables from current UIs
    switch str{val}
    case '9STA'
        bss_vec.name = '9STA';
        bss_vec.num_tx = str2num(string(h_9STA_num_tx.String{h_9STA_num_tx.Value}));
        bss_vec.num_rx = str2num(string(h_9STA_num_rx.String{h_9STA_num_rx.Value}));
        bss_vec.bss_cc = str2num(string(h_9STA_bss_cc.String{h_9STA_bss_cc.Value}));
        bss_vec.tx_power = str2num(string(h_9STA_tx_power.String));
        bss_vec.AP_pos = str2num(string(h_9STA_AP_pos.String));
        bss_vec.ch = h_9STA_ch.Value;
        
        bss_vec.STAs_pos= [];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA1_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA2_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA3_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA4_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA5_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA6_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA7_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA8_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_9STA_STA9_pos.String))];
        
        bss_vec.STAs_mcs= [];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA1_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA2_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA3_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA4_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA5_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA6_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA7_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA8_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_9STA_STA9_mcs.Value-1];
        
        bss_vec.STAs_apep= [];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA1_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA2_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA3_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA4_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA5_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA6_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA7_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA8_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_9STA_STA9_apep.String))];
        
        bss_vec.STAs_sts= [];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA1_sts.String{h_9STA_STA1_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA2_sts.String{h_9STA_STA2_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA3_sts.String{h_9STA_STA3_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA4_sts.String{h_9STA_STA4_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA5_sts.String{h_9STA_STA5_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA6_sts.String{h_9STA_STA6_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA7_sts.String{h_9STA_STA7_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA8_sts.String{h_9STA_STA8_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_9STA_STA9_sts.String{h_9STA_STA9_sts.Value}))];      
        
        bss_vec.STAs_load= {};
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA1_load.String{h_9STA_STA1_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA2_load.String{h_9STA_STA2_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA3_load.String{h_9STA_STA3_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA4_load.String{h_9STA_STA4_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA5_load.String{h_9STA_STA5_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA6_load.String{h_9STA_STA6_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA7_load.String{h_9STA_STA7_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA8_load.String{h_9STA_STA8_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_9STA_STA9_load.String{h_9STA_STA9_load.Value}];

        % add new member to existing all_bss cell array
        all_bss{end+1} = bss_vec;
        plot_all_bss_obstacles(all_bss, all_obstacles);
        
        % update all paths combinations
        all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
        all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
        all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
        all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);
        
        % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
        all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
        all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
        all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
        all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

        % add new member to remove list and update list
        string_tmp = string(h_bss_vec_popup.String);
        if strcmp(string_tmp,'')
            string_tmp{end} = '9STA';
        else
            string_tmp{end+1} = '9STA';
        end
        h_bss_vec_popup.String = string_tmp;

        % update path AP and BSS popups, also empty case
        string_tmp = string(h_bss_vec_popup.String);
        if ~strcmp(string_tmp,'')
            h_path_ap_tx_popup.String = ["";string_tmp];
            h_path_ap_rx_popup.String = ["";string_tmp];
        else
         h_path_ap_tx_popup.String = string_tmp;
            h_path_ap_rx_popup.String = string_tmp;
        end
        
        h_path_ap_tx_popup.Value = 1;
        h_path_ap_rx_popup.Value = 1;

    case '4STA' 
        bss_vec.name = '4STA';
        bss_vec.num_tx = str2num(string(h_4STA_num_tx.String{h_4STA_num_tx.Value}));
        bss_vec.num_rx = str2num(string(h_4STA_num_rx.String{h_4STA_num_rx.Value}));
        bss_vec.bss_cc = str2num(string(h_4STA_bss_cc.String{h_4STA_bss_cc.Value}));
        bss_vec.tx_power = str2num(string(h_4STA_tx_power.String));
        bss_vec.AP_pos = str2num(string(h_4STA_AP_pos.String));
        bss_vec.ch = h_4STA_ch.Value;

        bss_vec.STAs_pos= [];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_4STA_STA1_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_4STA_STA2_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_4STA_STA3_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_4STA_STA4_pos.String))];
        
        bss_vec.STAs_mcs= [];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_4STA_STA1_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_4STA_STA2_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_4STA_STA3_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_4STA_STA4_mcs.Value-1];
        
        bss_vec.STAs_apep= [];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_4STA_STA1_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_4STA_STA2_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_4STA_STA3_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_4STA_STA4_apep.String))];
        
        bss_vec.STAs_sts= [];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_4STA_STA1_sts.String{h_4STA_STA1_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_4STA_STA2_sts.String{h_4STA_STA2_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_4STA_STA3_sts.String{h_4STA_STA3_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_4STA_STA4_sts.String{h_4STA_STA4_sts.Value}))];
        
        bss_vec.STAs_load= {};
        bss_vec.STAs_load = [bss_vec.STAs_load; h_4STA_STA1_load.String{h_4STA_STA1_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_4STA_STA2_load.String{h_4STA_STA2_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_4STA_STA3_load.String{h_4STA_STA3_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_4STA_STA4_load.String{h_4STA_STA4_load.Value}];

        % add new member to existing all_bss cell array
        all_bss{end+1} = bss_vec;
        plot_all_bss_obstacles(all_bss, all_obstacles);
        
        % update all paths combinations
        all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
        all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
        all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
        all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

        % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
        all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
        all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
        all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
        all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

        % add new member to remove list and update list
        string_tmp = string(h_bss_vec_popup.String);
        if strcmp(string_tmp,'')
            string_tmp{end} = '4STA';
        else
            string_tmp{end+1} = '4STA';
        end
        h_bss_vec_popup.String = string_tmp;

        % update path AP and BSS popups, also empty case
        string_tmp = string(h_bss_vec_popup.String);
        if ~strcmp(string_tmp,'')
            h_path_ap_tx_popup.String = ["";string_tmp];
            h_path_ap_rx_popup.String = ["";string_tmp];
        else
            h_path_ap_tx_popup.String = string_tmp;
            h_path_ap_rx_popup.String = string_tmp;
        end
        
        h_path_ap_tx_popup.Value = 1;
        h_path_ap_rx_popup.Value = 1;

    case '2STA' 
        bss_vec.name = '2STA';
        bss_vec.num_tx = str2num(string(h_2STA_num_tx.String{h_2STA_num_tx.Value}));
        bss_vec.num_rx = str2num(string(h_2STA_num_rx.String{h_2STA_num_rx.Value}));
        bss_vec.bss_cc = str2num(string(h_2STA_bss_cc.String{h_2STA_bss_cc.Value}));
        bss_vec.tx_power = str2num(string(h_2STA_tx_power.String));
        bss_vec.AP_pos = str2num(string(h_2STA_AP_pos.String));
        bss_vec.ch = h_2STA_ch.Value;
        
        bss_vec.STAs_pos= [];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_2STA_STA1_pos.String))];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_2STA_STA2_pos.String))];
        
        bss_vec.STAs_mcs= [];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_2STA_STA1_mcs.Value-1];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_2STA_STA2_mcs.Value-1];
        
        bss_vec.STAs_apep= [];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_2STA_STA1_apep.String))];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_2STA_STA2_apep.String))];
        
        bss_vec.STAs_sts= [];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_2STA_STA1_sts.String{h_2STA_STA1_sts.Value}))];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_2STA_STA2_sts.String{h_2STA_STA2_sts.Value}))];
        
        bss_vec.STAs_load= {};
        bss_vec.STAs_load = [bss_vec.STAs_load; h_2STA_STA1_load.String{h_2STA_STA1_load.Value}];
        bss_vec.STAs_load = [bss_vec.STAs_load; h_2STA_STA2_load.String{h_2STA_STA2_load.Value}];

        % add new member to existing all_bss cell array
        all_bss{end+1} = bss_vec;
        plot_all_bss_obstacles(all_bss, all_obstacles);
        
        % update all paths combinations
        all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
        all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
        all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
        all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

        % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
        all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
        all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
        all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
        all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

        % add new member to remove list and update list
        string_tmp = string(h_bss_vec_popup.String);
        if strcmp(string_tmp,'')
            string_tmp{end} = '2STA';
        else
            string_tmp{end+1} = '2STA';
        end
        h_bss_vec_popup.String = string_tmp;

        % update path AP and BSS popups, also empty case
        string_tmp = string(h_bss_vec_popup.String);
        if ~strcmp(string_tmp,'')
            h_path_ap_tx_popup.String = ["";string_tmp];
            h_path_ap_rx_popup.String = ["";string_tmp];
        else
            h_path_ap_tx_popup.String = string_tmp;
            h_path_ap_rx_popup.String = string_tmp;
        end
        
        h_path_ap_tx_popup.Value = 1;
        h_path_ap_rx_popup.Value = 1;

    case '1STA' 
        bss_vec.name = '1STA';
        bss_vec.num_tx = str2num(string(h_1STA_num_tx.String{h_1STA_num_tx.Value}));
        bss_vec.num_rx = str2num(string(h_1STA_num_rx.String{h_1STA_num_rx.Value}));
        bss_vec.bss_cc = str2num(string(h_1STA_bss_cc.String{h_1STA_bss_cc.Value}));
        bss_vec.tx_power = str2num(string(h_1STA_tx_power.String));
        bss_vec.AP_pos = str2num(string(h_1STA_AP_pos.String));
        bss_vec.ch = h_1STA_ch.Value;

        bss_vec.STAs_pos= [];
        bss_vec.STAs_pos = [bss_vec.STAs_pos; str2num(string(h_1STA_STA1_pos.String))];
        
        bss_vec.STAs_mcs= [];
        bss_vec.STAs_mcs = [bss_vec.STAs_mcs; h_1STA_STA1_mcs.Value-1];
        
        bss_vec.STAs_apep= [];
        bss_vec.STAs_apep = [bss_vec.STAs_apep; str2num(string(h_1STA_STA1_apep.String))];
        
        bss_vec.STAs_sts= [];
        bss_vec.STAs_sts = [bss_vec.STAs_sts; str2num(string(h_1STA_STA1_sts.String{h_1STA_STA1_sts.Value}))];
        
        bss_vec.STAs_load= {};
        bss_vec.STAs_load = [bss_vec.STAs_load; h_1STA_STA1_load.String{h_1STA_STA1_load.Value}];

        % add new member to existing all_bss cell array
        all_bss{end+1} = bss_vec;
        plot_all_bss_obstacles(all_bss, all_obstacles);
        
        % update all paths combinations
        all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
        all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
        all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
        all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

        % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
        all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
        all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
        all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
        all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

        % add new member to remove list and update list
        string_tmp = string(h_bss_vec_popup.String);
        if strcmp(string_tmp,'')
            string_tmp{end} = '1STA';
        else
            string_tmp{end+1} = '1STA';
        end
        h_bss_vec_popup.String = string_tmp;

        % update path AP and BSS popups, also empty case
        string_tmp = string(h_bss_vec_popup.String);
        if ~strcmp(string_tmp,'')
            h_path_ap_tx_popup.String = ["";string_tmp];
            h_path_ap_rx_popup.String = ["";string_tmp];
        else
            h_path_ap_tx_popup.String = string_tmp;
            h_path_ap_rx_popup.String = string_tmp;
        end
        
        h_path_ap_tx_popup.Value = 1;
        h_path_ap_rx_popup.Value = 1;

    case 'Other'
        % do nothing right now
        
    end
end

% **********************************************************************************************************************
% Push button callback REMOVE BSS 
function remove_bss_pushbtn_Callback(source,eventdata) 
    
    % Determine the selected bss type
    val = h_bss_vec_popup.Value;
    cell_tmp = cellstr(h_bss_vec_popup.String);
    numBSS = numel(all_bss);
    
    % remove selected BSS and update text box
    if numBSS > 1
        all_bss(val) = [];
        numBSS = numBSS-1;
        cell_tmp(val) = [];
        if val > numBSS
            val = val-1;
        end
        h_bss_vec_popup.Value = val;
        h_bss_vec_popup.String = cell_tmp;            
    elseif numBSS == 1
        if ~strcmp(cell_tmp,'')
            all_bss(val) = [];
            cell_tmp(val) = {''};
            h_bss_vec_popup.Value = val;
            h_bss_vec_popup.String = cell_tmp;             
        end
    end
    
    % update plot         
    plot_all_bss_obstacles(all_bss, all_obstacles);
    
    % update all paths combinations
    all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
    all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
    all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
    all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

    % update path AP and BSS popups, also empty case
    string_tmp = string(h_bss_vec_popup.String);
    h_path_ap_tx_popup.Value = 1;
    h_path_ap_rx_popup.Value = 1;
    if ~strcmp(string_tmp,'')
        h_path_ap_tx_popup.String = ["";string_tmp];
        h_path_ap_rx_popup.String = ["";string_tmp];
    else
        h_path_ap_tx_popup.String = {string_tmp};
        h_path_ap_rx_popup.String = {string_tmp};
    end
end

% **********************************************************************************************************************
% Push button callback SELECT BSS 
function select_bss_pushbtn_Callback(source,eventdata) 
    
    % Determine the selected bss type
    val = h_bss_vec_popup.Value;
    cell_tmp = cellstr(h_bss_vec_popup.String);
    numBSS = numel(all_bss);
    
    % check for empty space
    if numBSS < 1
        return;
    end
    
    % Select right template and load data into template
    name = all_bss{val}.name;
    
    % map value for later add callback
    [~,h_bss_popup.Value] = ismember(name,{'9STA','4STA','2STA','1STA','Other'});
    
    % switch off all bss panels
    h_pan_9STA.Visible = 'off';
    h_pan_4STA.Visible = 'off';
    h_pan_2STA.Visible = 'off';
    h_pan_1STA.Visible = 'off';
    
    switch name
        case '9STA'
            h_pan_9STA.Visible = 'on';
            
            h_9STA_num_tx.Value = all_bss{val}.num_tx;
            h_9STA_num_rx.Value = all_bss{val}.num_rx;
            h_9STA_bss_cc.Value = all_bss{val}.bss_cc;
            h_9STA_tx_power.String = {num2str(all_bss{val}.tx_power(1))};
            h_9STA_AP_pos.String = {num2str(all_bss{val}.AP_pos)};
            h_9STA_ch.Value = all_bss{val}.ch;

            h_9STA_STA1_pos.String = {num2str(all_bss{val}.STAs_pos(1,:))};
            h_9STA_STA2_pos.String = {num2str(all_bss{val}.STAs_pos(2,:))};
            h_9STA_STA3_pos.String = {num2str(all_bss{val}.STAs_pos(3,:))};
            h_9STA_STA4_pos.String = {num2str(all_bss{val}.STAs_pos(4,:))};
            h_9STA_STA5_pos.String = {num2str(all_bss{val}.STAs_pos(5,:))};
            h_9STA_STA6_pos.String = {num2str(all_bss{val}.STAs_pos(6,:))};
            h_9STA_STA7_pos.String = {num2str(all_bss{val}.STAs_pos(7,:))};
            h_9STA_STA8_pos.String = {num2str(all_bss{val}.STAs_pos(8,:))};
            h_9STA_STA9_pos.String = {num2str(all_bss{val}.STAs_pos(9,:))};
            
            h_9STA_STA1_mcs.Value = all_bss{val}.STAs_mcs(1)+1;
            h_9STA_STA2_mcs.Value = all_bss{val}.STAs_mcs(2)+1;
            h_9STA_STA3_mcs.Value = all_bss{val}.STAs_mcs(3)+1;
            h_9STA_STA4_mcs.Value = all_bss{val}.STAs_mcs(4)+1;
            h_9STA_STA5_mcs.Value = all_bss{val}.STAs_mcs(5)+1;
            h_9STA_STA6_mcs.Value = all_bss{val}.STAs_mcs(6)+1;
            h_9STA_STA7_mcs.Value = all_bss{val}.STAs_mcs(7)+1;
            h_9STA_STA8_mcs.Value = all_bss{val}.STAs_mcs(8)+1;
            h_9STA_STA9_mcs.Value = all_bss{val}.STAs_mcs(9)+1;

            h_9STA_STA1_apep.String = {num2str(all_bss{val}.STAs_apep(1))};
            h_9STA_STA2_apep.String = {num2str(all_bss{val}.STAs_apep(2))};
            h_9STA_STA3_apep.String = {num2str(all_bss{val}.STAs_apep(3))};
            h_9STA_STA4_apep.String = {num2str(all_bss{val}.STAs_apep(4))};
            h_9STA_STA5_apep.String = {num2str(all_bss{val}.STAs_apep(5))};
            h_9STA_STA6_apep.String = {num2str(all_bss{val}.STAs_apep(6))};
            h_9STA_STA7_apep.String = {num2str(all_bss{val}.STAs_apep(7))};
            h_9STA_STA8_apep.String = {num2str(all_bss{val}.STAs_apep(8))};
            h_9STA_STA9_apep.String = {num2str(all_bss{val}.STAs_apep(9))};

            h_9STA_STA1_sts.Value = all_bss{val}.STAs_sts(1);
            h_9STA_STA2_sts.Value = all_bss{val}.STAs_sts(2);
            h_9STA_STA3_sts.Value = all_bss{val}.STAs_sts(3);
            h_9STA_STA4_sts.Value = all_bss{val}.STAs_sts(4);
            h_9STA_STA5_sts.Value = all_bss{val}.STAs_sts(5);
            h_9STA_STA6_sts.Value = all_bss{val}.STAs_sts(6);
            h_9STA_STA7_sts.Value = all_bss{val}.STAs_sts(7);
            h_9STA_STA8_sts.Value = all_bss{val}.STAs_sts(8);
            h_9STA_STA9_sts.Value = all_bss{val}.STAs_sts(9);
            
            [~,h_9STA_STA1_load.Value] = ismember(all_bss{val}.STAs_load(1),load_vec);
            [~,h_9STA_STA2_load.Value] = ismember(all_bss{val}.STAs_load(2),load_vec);
            [~,h_9STA_STA3_load.Value] = ismember(all_bss{val}.STAs_load(3),load_vec);
            [~,h_9STA_STA4_load.Value] = ismember(all_bss{val}.STAs_load(4),load_vec);
            [~,h_9STA_STA5_load.Value] = ismember(all_bss{val}.STAs_load(5),load_vec);
            [~,h_9STA_STA6_load.Value] = ismember(all_bss{val}.STAs_load(6),load_vec);
            [~,h_9STA_STA7_load.Value] = ismember(all_bss{val}.STAs_load(7),load_vec);
            [~,h_9STA_STA8_load.Value] = ismember(all_bss{val}.STAs_load(8),load_vec);
            [~,h_9STA_STA9_load.Value] = ismember(all_bss{val}.STAs_load(9),load_vec);
            
        case '4STA'
            h_pan_4STA.Visible = 'on';
            
            h_4STA_num_tx.Value = all_bss{val}.num_tx;
            h_4STA_num_rx.Value = all_bss{val}.num_rx;
            h_4STA_bss_cc.Value = all_bss{val}.bss_cc;
            h_4STA_tx_power.String = {num2str(all_bss{val}.tx_power(1))};
            h_4STA_AP_pos.String = {num2str(all_bss{val}.AP_pos)};
            h_4STA_ch.Value = all_bss{val}.ch;

            h_4STA_STA1_pos.String = {num2str(all_bss{val}.STAs_pos(1,:))};
            h_4STA_STA2_pos.String = {num2str(all_bss{val}.STAs_pos(2,:))};
            h_4STA_STA3_pos.String = {num2str(all_bss{val}.STAs_pos(3,:))};
            h_4STA_STA4_pos.String = {num2str(all_bss{val}.STAs_pos(4,:))};
            
            h_4STA_STA1_mcs.Value = all_bss{val}.STAs_mcs(1)+1;
            h_4STA_STA2_mcs.Value = all_bss{val}.STAs_mcs(2)+1;
            h_4STA_STA3_mcs.Value = all_bss{val}.STAs_mcs(3)+1;
            h_4STA_STA4_mcs.Value = all_bss{val}.STAs_mcs(4)+1;

            h_4STA_STA1_apep.String = {num2str(all_bss{val}.STAs_apep(1))};
            h_4STA_STA2_apep.String = {num2str(all_bss{val}.STAs_apep(2))};
            h_4STA_STA3_apep.String = {num2str(all_bss{val}.STAs_apep(3))};
            h_4STA_STA4_apep.String = {num2str(all_bss{val}.STAs_apep(4))};

            h_4STA_STA1_sts.Value = all_bss{val}.STAs_sts(1);
            h_4STA_STA2_sts.Value = all_bss{val}.STAs_sts(2);
            h_4STA_STA3_sts.Value = all_bss{val}.STAs_sts(3);
            h_4STA_STA4_sts.Value = all_bss{val}.STAs_sts(4);
            
            [~,h_4STA_STA1_load.Value] = ismember(all_bss{val}.STAs_load(1),load_vec);
            [~,h_4STA_STA2_load.Value] = ismember(all_bss{val}.STAs_load(2),load_vec);
            [~,h_4STA_STA3_load.Value] = ismember(all_bss{val}.STAs_load(3),load_vec);
            [~,h_4STA_STA4_load.Value] = ismember(all_bss{val}.STAs_load(4),load_vec);           
            
        case '2STA'
            h_pan_2STA.Visible = 'on';
            
            h_2STA_num_tx.Value = all_bss{val}.num_tx;
            h_2STA_num_rx.Value = all_bss{val}.num_rx;
            h_2STA_bss_cc.Value = all_bss{val}.bss_cc;
            h_2STA_tx_power.String = {num2str(all_bss{val}.tx_power(1))};
            h_2STA_AP_pos.String = {num2str(all_bss{val}.AP_pos)};
            h_2STA_ch.Value = all_bss{val}.ch;

            h_2STA_STA1_pos.String = {num2str(all_bss{val}.STAs_pos(1,:))};
            h_2STA_STA2_pos.String = {num2str(all_bss{val}.STAs_pos(2,:))};
            
            h_2STA_STA1_mcs.Value = all_bss{val}.STAs_mcs(1)+1;
            h_2STA_STA2_mcs.Value = all_bss{val}.STAs_mcs(2)+1;

            h_2STA_STA1_apep.String = {num2str(all_bss{val}.STAs_apep(1))};
            h_2STA_STA2_apep.String = {num2str(all_bss{val}.STAs_apep(2))};

            h_2STA_STA1_sts.Value = all_bss{val}.STAs_sts(1);
            h_2STA_STA2_sts.Value = all_bss{val}.STAs_sts(2);
            
            [~,h_2STA_STA1_load.Value] = ismember(all_bss{val}.STAs_load(1),load_vec);
            [~,h_2STA_STA2_load.Value] = ismember(all_bss{val}.STAs_load(2),load_vec);
            
        case '1STA'
            h_pan_1STA.Visible = 'on';

            h_1STA_num_tx.Value = all_bss{val}.num_tx;
            h_1STA_num_rx.Value = all_bss{val}.num_rx;
            h_1STA_bss_cc.Value = all_bss{val}.bss_cc;
            h_1STA_tx_power.String = {num2str(all_bss{val}.tx_power(1))};
            h_1STA_AP_pos.String = {num2str(all_bss{val}.AP_pos)};
            h_1STA_ch.Value = all_bss{val}.ch;

            h_1STA_STA1_pos.String = {num2str(all_bss{val}.STAs_pos(1,:))};
            
            h_1STA_STA1_mcs.Value = all_bss{val}.STAs_mcs(1)+1;

            h_1STA_STA1_apep.String = {num2str(all_bss{val}.STAs_apep(1))};

            h_1STA_STA1_sts.Value = all_bss{val}.STAs_sts(1);
            
            [~,h_1STA_STA1_load.Value] = ismember(all_bss{val}.STAs_load(1),load_vec);
            
    end
    
    % flash selected BSS
    h_axes_space.XLimMode = 'manual';
    h_axes_space.YLimMode = 'manual';
    h_axes_space.ZLimMode = 'manual';
    
    for id = 1:3                        
        h_AP_space{val}.Visible ='off';
        h_STA_space{val}.Visible ='off';
        drawnow;
        pause(0.1)                     
        h_AP_space{val}.Visible ='on';
        h_STA_space{val}.Visible ='on';
        drawnow;
        pause(0.1)                      
    end    
    
    h_axes_space.XLimMode = 'auto';
    h_axes_space.YLimMode = 'auto';
    h_axes_space.ZLimMode = 'auto';
    
end

% **********************************************************************************************************************
% Push button callback MODIFY BSS 
function modify_bss_pushbtn_Callback(source,eventdata) 
    
    % modify is delete current selected BSS and add new one
    % use add callback but make sure to set BSS type correctly
    
    % Determine the selected bss type
    val = h_bss_vec_popup.Value;
    cell_tmp = cellstr(h_bss_vec_popup.String);
    numBSS = numel(all_bss);
    
    % check for error
    if numBSS < 1
        return;
    end
    
    % remove selected BSS and update text box
    if numBSS > 1
        all_bss(val) = [];
        numBSS = numBSS-1;
        cell_tmp(val) = [];
        if val > numBSS
            val = val-1;
        end
        h_bss_vec_popup.Value = val;
        h_bss_vec_popup.String = cell_tmp;            
    elseif numBSS == 1
        if ~strcmp(cell_tmp,'')
            all_bss(val) = [];
            cell_tmp(val) = {''};
            h_bss_vec_popup.Value = val;
            h_bss_vec_popup.String = cell_tmp;             
        end
    end
    
    % add modified BSS
    add_bss_pushbtn_Callback(source,eventdata);
    
end

% **********************************************************************************************************************
% Push button callback ADD OBSTACLE
function add_obstacle_pushbtn_Callback(source,eventdata) 
    
    % Determine the selected obstacle type
    str = h_obstacle_popup.String;
    val = h_obstacle_popup.Value;
    
    % Load variables from current UIs
    switch str{val};
        case 'Floor'
            obstacle_vec.type = 'Floor';
            obstacle_vec.pos = [];
            obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos1.String))];
            obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos2.String))];
            obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos3.String))];
            obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos4.String))];

            % add new member to existing all_obstacle cell array
            all_obstacles{end+1} = obstacle_vec;
            plot_all_bss_obstacles(all_bss, all_obstacles);
            
            % update all paths combinations
            all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
            all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
            all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
            all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);
            
            % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
            all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
            all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
            all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
            all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

            % add new member to remove list and update list
            string_tmp = string(h_obstacle_vec_popup.String);
            if strcmp(string_tmp,'')
                string_tmp{end} = 'Floor';
            else
                string_tmp{end+1} = 'Floor';
            end
            h_obstacle_vec_popup.String = string_tmp;

            % update path AP and LINK popups, also empty case
            string_tmp = string(h_bss_vec_popup.String);
            if ~strcmp(string_tmp,'')
                h_path_ap_tx_popup.String = ["";string_tmp];
                h_path_ap_rx_popup.String = ["";string_tmp];
            else
                h_path_ap_tx_popup.String = string_tmp;
                h_path_ap_rx_popup.String = string_tmp;
            end
            h_path_ap_tx_popup.Value = 1;
            h_path_ap_rx_popup.Value = 1;

        case 'Wall'             
        obstacle_vec.type = 'Wall';
        obstacle_vec.pos = [];
        obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos1.String))];
        obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos2.String))];
        obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos3.String))];
        obstacle_vec.pos = [obstacle_vec.pos; str2num(string(h_obstacle_pos4.String))];

        % add new member to existing all_obstacle cell array
        all_obstacles{end+1} = obstacle_vec;
        plot_all_bss_obstacles(all_bss, all_obstacles);
        
        % update all paths combinations
        all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
        all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
        all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
        all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);
        
        % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
        all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
        all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
        all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
        all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

        % add new member to remove list and update list
        string_tmp = string(h_obstacle_vec_popup.String);
        if strcmp(string_tmp,'')
            string_tmp{end} = 'Wall';
        else
            string_tmp{end+1} = 'Wall';
        end
        h_obstacle_vec_popup.String = string_tmp;             

        % update path AP and LINK popups, also empty case
        string_tmp = string(h_bss_vec_popup.String);
        if ~strcmp(string_tmp,'')
            h_path_ap_tx_popup.String = ["";string_tmp];
            h_path_ap_rx_popup.String = ["";string_tmp];
        else
            h_path_ap_tx_popup.String = string_tmp;
            h_path_ap_rx_popup.String = string_tmp;
        end
        h_path_ap_tx_popup.Value = 1;
        h_path_ap_rx_popup.Value = 1;
        
    end
end

% **********************************************************************************************************************
% Push button callback REMOVE OBSTACLE 
function remove_obstacle_pushbtn_Callback(source,eventdata)
    
    % Determine the selected obstacle type
    val = h_obstacle_vec_popup.Value;
    cell_tmp = cellstr(h_obstacle_vec_popup.String);
    numObstacle = numel(all_obstacles);
    
    % remove selected obstacle and update text box
    if numObstacle > 1
        all_obstacles(val) = [];
        numObstacle = numObstacle-1;
        cell_tmp(val) = [];
        if val > numObstacle
            val = val-1;
        end
        h_obstacle_vec_popup.Value = val;
        h_obstacle_vec_popup.String = cell_tmp;            
    elseif numObstacle == 1
        if ~strcmp(cell_tmp,'')
            all_obstacles(val) = [];
            cell_tmp(val) = {''};
            h_obstacle_vec_popup.Value = val;
            h_obstacle_vec_popup.String = cell_tmp;             
        end
    end
    
    % update plot         
    plot_all_bss_obstacles(all_bss, all_obstacles);
    % update all paths combinations
    all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
    all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
    all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
    all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);

    % update path AP and LINK popups, also empty case
    string_tmp = string(h_bss_vec_popup.String);
    if ~strcmp(string_tmp,'')
        h_path_ap_tx_popup.String = ["";string_tmp];
        h_path_ap_rx_popup.String = ["";string_tmp];
    else
        h_path_ap_tx_popup.String = string_tmp;
        h_path_ap_rx_popup.String = string_tmp;
    end
    h_path_ap_tx_popup.Value = 1;
    h_path_ap_rx_popup.Value = 1;
        
end

% **********************************************************************************************************************
% Push button callback SELECT OBSTACLE 
function select_obstacle_pushbtn_Callback(source,eventdata)
    
    
    % Determine the selected obstacle type
    val = h_obstacle_vec_popup.Value;
    cell_tmp = cellstr(h_obstacle_vec_popup.String);
    numObstacle = numel(all_obstacles);
    
    % check for empty space
    if numObstacle < 1
        return;
    end
    
    % Select right template and load data into template
    type = all_obstacles{val}.type;
    
    % map value for later add callback
    [~,h_obstacle_popup.Value] = ismember(type,{'Wall','Floor'});
       
    h_obstacle_pos1.String = {num2str(all_obstacles{val}.pos(1,:))};
    h_obstacle_pos2.String = {num2str(all_obstacles{val}.pos(2,:))};
    h_obstacle_pos3.String = {num2str(all_obstacles{val}.pos(3,:))};
    h_obstacle_pos4.String = {num2str(all_obstacles{val}.pos(4,:))};
        
    % flash selected obstacle
    h_axes_space.XLimMode = 'manual';
    h_axes_space.YLimMode = 'manual';
    h_axes_space.ZLimMode = 'manual';
    
    for id = 1:3                        
        h_OB_space{val}.Visible ='off';
        drawnow;
        pause(0.1)                     
        h_OB_space{val}.Visible ='on';
        drawnow;
        pause(0.1)                      
    end    
    
    h_axes_space.XLimMode = 'auto';
    h_axes_space.YLimMode = 'auto';
    h_axes_space.ZLimMode = 'auto';
    
end

% **********************************************************************************************************************
% Push button callback MODIFY OBSTACLE 
function modify_obstacle_pushbtn_Callback(source,eventdata)
    
    % modify is delete current selected obstacle and add new one
    % use add callback but make sure to set obstacle type correctly
    
    % Determine the selected obstacle type
    val = h_obstacle_vec_popup.Value;
    cell_tmp = cellstr(h_obstacle_vec_popup.String);
    numObstacle = numel(all_obstacles);
    
    % check for empty space
    if numObstacle < 1
        return;
    end
    
    % remove selected obstacle and update text box
    if numObstacle > 1
        all_obstacles(val) = [];
        numObstacle = numObstacle-1;
        cell_tmp(val) = [];
        if val > numObstacle
            val = val-1;
        end
        h_obstacle_vec_popup.Value = val;
        h_obstacle_vec_popup.String = cell_tmp;            
    elseif numObstacle == 1
        if ~strcmp(cell_tmp,'')
            all_obstacles(val) = [];
            cell_tmp(val) = {''};
            h_obstacle_vec_popup.Value = val;
            h_obstacle_vec_popup.String = cell_tmp;             
        end
    end
    
    % add modified obstacle
    add_obstacle_pushbtn_Callback(source,eventdata);
    
end

% **********************************************************************************************************************
% path_bss_tx_popup_Callback to drive STA selection popup 
function path_bss_tx_popup_Callback(source,eventdata) 
    
    % plot path and PL values
    if (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % AP to AP
        plotAP_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % STA to AP
        plotSTA_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % STA to STA
        plotSTA_STA();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % AP to STA
        plotAP_STA();        
    else
        % clear line and values
        clearLineValues();
    end
    
    % populate STA list for own AP
    if (h_path_ap_tx_popup.Value > 1)
        idxBSS = h_path_ap_tx_popup.Value - 1;
        numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
        % create string array of STAs, also empty case
        string_tmp = '';
        for idx = 1:numSTAs
            string_tmp = [string_tmp; strcat('STA',num2str(idx))];
        end
        % update STA RX popup accordingly
        h_path_sta_tx_popup.String = ["";string_tmp];
        h_path_sta_tx_popup.Value = 1;
    else
        h_path_sta_tx_popup.String = {''};
        h_path_sta_tx_popup.Value = 1;             
    end
    
end

% **********************************************************************************************************************
% path_bss_rx_popup_Callback to drive STA selection popup 
function path_bss_rx_popup_Callback(source,eventdata) 
    
      
    % plot path and PL values
    if (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % AP to AP
        plotAP_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % STA to AP
        plotSTA_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % STA to STA
        plotSTA_STA();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % AP to STA
        plotAP_STA();        
    else
        % clear line and values
        clearLineValues();
    end
    
    % populate STA list for own AP
    if (h_path_ap_rx_popup.Value > 1)
        idxBSS = h_path_ap_rx_popup.Value - 1;
        numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
        % create string array of STAs, also empty case
        string_tmp = '';
        for idx = 1:numSTAs
            string_tmp = [string_tmp; strcat('STA',num2str(idx))];
        end
        % update STA RX popup accordingly
        h_path_sta_rx_popup.String = ["";string_tmp];
        h_path_sta_rx_popup.Value = 1;
    else
        h_path_sta_rx_popup.String = {''};
        h_path_sta_rx_popup.Value = 1;             
    end
        
end

% **********************************************************************************************************************
% path_sta_tx_popup_Callback to drive path display after STA selection 
function path_sta_tx_popup_Callback(source,eventdata)    
       
    % plot path and PL values
    if (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % AP to AP
        plotAP_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % STA to AP
        plotSTA_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % STA to STA
        plotSTA_STA();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % AP to STA
        plotAP_STA();        
    else
        % clear line and values
        clearLineValues();
    end
    
end

% **********************************************************************************************************************
% path_sta_rx_popup_Callback to drive path display after STA selection 
function path_sta_rx_popup_Callback(source,eventdata) 
    
    % plot path and PL values
    if (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % AP to AP
        plotAP_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value == 1)       
        % STA to AP
        plotSTA_AP();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value > 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % STA to STA
        plotSTA_STA();        
    elseif (h_path_ap_tx_popup.Value > 1) && (h_path_sta_tx_popup.Value == 1) && ...
            (h_path_ap_rx_popup.Value > 1) && (h_path_sta_rx_popup.Value > 1)       
        % AP to STA
        plotAP_STA();        
    else
        % clear line and values
        clearLineValues();
    end
    
end

% **********************************************************************************************************************
% Pop-up menu callback PATHLOSS MODEL
function pathloss_model_popup_Callback(source,eventdata) 

    % switch off all pathloss panels
    h_pan_pathloss_tgax.Visible = 'off';
    h_pan_pathloss_etapl.Visible = 'off';

    % Determine the selected simu type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
        case 'TGax'
            h_pan_pathloss_tgax.Visible = 'on';
            
        case 'EtaPowerLaw'
            h_pan_pathloss_etapl.Visible = 'on';
            
        case 'Other'
            % do nothing right now
    end
    
    % load / reload PL relevant parameters
    simulation.ChannelModel = string(h_channel_popup.String{h_channel_popup.Value});           
    simulation.DelayProfile = string(h_tgax_DelayProfile.String{h_tgax_DelayProfile.Value});           
    simulation.w2Scenario = string(h_w2_Scenario.String{h_w2_Scenario.Value});           
    simulation.w2PropCondition = string(h_w2_PropCondition.String{h_w2_PropCondition.Value});           
    simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
    simulation.LargeScaleFadingEffect = ...
        string(h_LargeScaleFadingEffect_tgax.String{h_LargeScaleFadingEffect_tgax.Value});
    simulation.WallPenetrationLoss = string(h_WallPenetrationLoss_tgax.String{h_WallPenetrationLoss_tgax.Value});            
    simulation.BPDistance = str2num(string(h_BP_distance.String));
    simulation.etaBeforeBPDistance = str2num(string(h_eta_bBP_distance.String));
    simulation.etaAfterBPDistance = str2num(string(h_eta_aBP_distance.String));
    simulation.WallPenetrationLossEta = str2num(string(h_WallPenetrationLoss.String));
    simulation.FloorPenetrationLossEta = str2num(string(h_FloorPenetrationLoss.String));
    
    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);
    
    % update spatial view
    plot_all_bss_obstacles(all_bss, all_obstacles);
    
end

% **********************************************************************************************************************
% Pop-up menu callback CHANNEL MODEL
function channel_model_popup_Callback(source,eventdata) 

    % switch off all channel panels
    h_pan_channel_tgax.Visible = 'off';
    h_pan_channel_w2.Visible = 'off';

    % Determine the selected simu type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
        case 'TGax'
            h_pan_channel_tgax.Visible = 'on';
            
        case 'WINNER II'
            h_pan_channel_w2.Visible = 'on';
            
        case 'None'
            % do nothing right now
    end
    
    % update spatial view
    plot_all_bss_obstacles(all_bss, all_obstacles);
    
end

% **********************************************************************************************************************
% Pop-up menu callback SIMU TYPE
function simu_type_popup_Callback(source,eventdata) 

    % switch off all simu panels
    h_pan_A2B.Visible = 'off';
    h_pan_LOOP.Visible = 'off';

    % Determine the selected simu type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
        case 'CompareA2B'
            h_pan_A2B.Visible = 'on';
            h_simu_text.String = A2B_text;
            % trigger subpanels
            A2B_type_popupA_Callback(h_A2B_popupA,'');
            A2B_type_popupB_Callback(h_A2B_popupB,'');
            
        case 'LoopOver'
            h_pan_LOOP.Visible = 'on';
            h_simu_text.String = LOOP_text;
%             h_LOOP_popup.Value = 1;
            
        case 'Other'
            h_simu_text.String = '';
            % do nothing right now
    end
    
end

% **********************************************************************************************************************
% Pop-up menu callback SIMU TYPE A2B A selector
function A2B_type_popupA_Callback(source,eventdata) 
    % switch off all A panels
    h_pan_A2B_A1.Visible = 'off';
    h_pan_A2B_A8.Visible = 'off';
    h_pan_A2B_A9.Visible = 'off';

    % Determine the selected simu type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
        case 'CSMA/CA'
            h_pan_A2B_A1.Visible = 'on';

        case 'CSMA/SDMSR'
            h_pan_A2B_A8.Visible = 'on';

        case 'CSMA/SR'
            h_pan_A2B_A9.Visible = 'on';

        case 'Other'
            % do nothing right now

    end
    
end   

% **********************************************************************************************************************
%  Pop-up menu callback SIMU TYPE A2B B selector
function A2B_type_popupB_Callback(source,eventdata) 

    % switch off all B panels
    h_pan_A2B_B1.Visible = 'off';
    h_pan_A2B_B8.Visible = 'off';
    h_pan_A2B_B9.Visible = 'off';

    % Determine the selected simu type
    str = source.String;
    val = source.Value;
    
    % Set current active panel
    switch str{val}
        case 'CSMA/CA'
            h_pan_A2B_B1.Visible = 'on';

        case 'CSMA/SDMSR'
            h_pan_A2B_B8.Visible = 'on';

        case 'CSMA/SR'
            h_pan_A2B_B9.Visible = 'on';

        case 'Other'
            % do nothing right now
            
    end
    
end   

% **********************************************************************************************************************
% Push Btn callback SIMU START *****************************************************************************************
% **********************************************************************************************************************

% This callback passes all needed informations about BSSs, obstacles,
% paths and simulation parameters to one specific simulaton function.
% Return is statistics / plots about finished simulation
function start_simu_pushbtn_Callback(source,eventdata)
    
    % check if current configuration is supported
    simulation.PHYType = string(h_PHY_type.String{h_PHY_type.Value});
    simulation.w2PropCondition = string(h_w2_PropCondition.String{h_w2_PropCondition.Value});
    simulation.typeA = string(h_A2B_popupA.String{h_A2B_popupA.Value});
    simulation.typeB = string(h_A2B_popupB.String{h_A2B_popupB.Value});
    simulation.ChannelModel = string(h_channel_popup.String{h_channel_popup.Value});          
    simulation.A.BEAMFORMING = h_A2B_A1_BEAMFORMING.Value;
    simulation.B.BEAMFORMING = h_A2B_B1_BEAMFORMING.Value;
    % check values for SDMSR for beamforming
    simulation.BEAMFORMING = h_LOOP_BEAMFORMING.Value;
    [rc,reason] = CheckConfiguration(all_bss,simulation);
    if rc ~= 0
        msgbox({'The current configuration is not supported!';reason}, 'Error','error','modal');
        return;
    end
    
    % clear all old figures from previous runs
    Figures = findobj('Type','Figure','-not','Tag',get(h_win,'Tag'));
    close(Figures);
    
    % clear result arrays from previous runs
    resultU = {};
    resultB = {};
    
    % if currently stopped allow run
    % or if currently running stop execution in GEQ loop
    strT = h_start_simu_pushbtn.String;
    switch strT{1}
        case 'Start'
            h_start_simu_pushbtn.String = {'Cancel'};
            setappdata(h_start_simu_pushbtn,'cancelflag',0);
        case 'Cancel'
            h_start_simu_pushbtn.String = {'Start'};
            setappdata(h_start_simu_pushbtn,'cancelflag',1);
            return;
    end
    
    % Determine the selected simu type
    str = h_simu_popup.String;
    val = h_simu_popup.Value;
    
    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);
    
    % Activate simulation based on selected simulation
    switch str{val}

        case 'CompareA2B'
            simulation.approach = 'CompareA2B';
            simulation.time = str2num(string(h_time.String));
            simulation.LoadCycle = str2num(string(h_LoadCycle.String));
            simulation.PERSNROffset = str2num(string(h_PERSNROffset.String));
            simulation.DataQueueCycle = simulation.LoadCycle;
            simulation.handleTime = h_simu_time;
            simulation.handlenumPackets = h_simu_packets;
            simulation.ChannelModel = string(h_channel_popup.String{h_channel_popup.Value});           
            simulation.DelayProfile = string(h_tgax_DelayProfile.String{h_tgax_DelayProfile.Value});         
            simulation.w2Scenario = string(h_w2_Scenario.String{h_w2_Scenario.Value});           
            simulation.w2PropCondition = string(h_w2_PropCondition.String{h_w2_PropCondition.Value});           
            simulation.RandomStream = string(h_RandomStream.String{h_RandomStream.Value});           
            simulation.PHYType = string(h_PHY_type.String{h_PHY_type.Value});           
            simulation.ReportLevel = string(h_ReportLevel.String{h_ReportLevel.Value});
            simulation.RSNRBase = string(h_RSNRBase.String{h_RSNRBase.Value});           
            simulation.logging = h_DoLog.Value;
            simulation.resettgax = h_reset_stream.Value;
            simulation.resetchannel = h_reset_stream.Value;
%             simulation.usetgax = h_use_tgax.Value;
            simulation.useawgn = h_use_awgn.Value;
            simulation.ConstAvgPow = h_const_pow.Value;

            simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
            simulation.LargeScaleFadingEffect = ...
                string(h_LargeScaleFadingEffect_tgax.String{h_LargeScaleFadingEffect_tgax.Value});
            simulation.WallPenetrationLoss = string(h_WallPenetrationLoss_tgax.String{h_WallPenetrationLoss_tgax.Value});            
            simulation.BPDistance = str2num(string(h_BP_distance.String));
            simulation.etaBeforeBPDistance = str2num(string(h_eta_bBP_distance.String));
            simulation.etaAfterBPDistance = str2num(string(h_eta_aBP_distance.String));
            simulation.WallPenetrationLossEta = str2num(string(h_WallPenetrationLoss.String));
            simulation.FloorPenetrationLossEta = str2num(string(h_FloorPenetrationLoss.String));

            simulation.typeA = string(h_A2B_popupA.String{h_A2B_popupA.Value});
            strA = h_A2B_popupA.String;
            valA = h_A2B_popupA.Value;
            switch strA{valA}

                case 'CSMA/CA'
                    simulation.A.DRC = h_A2B_A1_DRC.Value;
                    simulation.A.NOINT = h_A2B_A1_NOINT.Value;
                    simulation.A.ESTSINR = h_A2B_A1_ESTSINR.Value;
                    simulation.A.BEAMFORMING = h_A2B_A1_BEAMFORMING.Value;

                case 'CSMA/SDMSR'
                    simulation.A.NOINT = false;
                    simulation.A.MA = string(h_A2B_A8_MA.String{h_A2B_A8_MA.Value});
                    simulation.A.VER = string(h_A2B_A8_VER.String{h_A2B_A8_VER.Value});
                    simulation.A.SchedAllocMethod = string(h_A2B_A8_SchedAlloc.String{h_A2B_A8_SchedAlloc.Value});
                    
                case 'CSMA/SR'
                    simulation.A.NOINT = false;
                    simulation.A.MA = string(h_A2B_A9_MA.String{h_A2B_A9_MA.Value});
                    simulation.A.VER = string(h_A2B_A9_VER.String{h_A2B_A9_VER.Value});
                    simulation.A.SchedAllocMethod = string(h_A2B_A9_SchedAlloc.String{h_A2B_A9_SchedAlloc.Value});
                    
                case 'Other'

            end

            simulation.typeB = string(h_A2B_popupB.String{h_A2B_popupB.Value});
            strB = h_A2B_popupB.String;
            valB = h_A2B_popupB.Value;
            switch strB{valB}
                
                case 'CSMA/CA'
                    simulation.B.DRC = h_A2B_B1_DRC.Value;
                    simulation.B.NOINT = h_A2B_B1_NOINT.Value;
                    simulation.B.ESTSINR = h_A2B_B1_ESTSINR.Value;
                    simulation.B.BEAMFORMING = h_A2B_B1_BEAMFORMING.Value;

                case 'CSMA/SDMSR'
                    simulation.B.NOINT = false;
                    simulation.B.MA = string(h_A2B_B8_MA.String{h_A2B_B8_MA.Value});
                    simulation.B.VER = string(h_A2B_B8_VER.String{h_A2B_B8_VER.Value});
                    simulation.B.SchedAllocMethod = string(h_A2B_B8_SchedAlloc.String{h_A2B_B8_SchedAlloc.Value});

                case 'CSMA/SR'
                    simulation.B.NOINT = false;
                    simulation.B.MA = string(h_A2B_B9_MA.String{h_A2B_B9_MA.Value});
                    simulation.B.VER = string(h_A2B_B9_VER.String{h_A2B_B9_VER.Value});
                    simulation.B.SchedAllocMethod = string(h_A2B_B9_SchedAlloc.String{h_A2B_B9_SchedAlloc.Value});

                case 'Other'
                
            end

            % pass over to simulation
            [resultU, resultB] = sim_A2B(all_bss, all_path_STA_DL, all_path_AP_DL, all_pathloss_STA_DL,...
                all_pathloss_AP_DL, all_path_STA_UL, all_path_AP_UL, all_pathloss_STA_UL,...
                all_pathloss_AP_UL, simulation, resultU, resultB, h_start_simu_pushbtn);

    case 'LoopOver'
        simulation.approach = 'LoopOver';
        simulation.time = str2num(string(h_time.String));
        simulation.LoadCycle = str2num(string(h_LoadCycle.String));
        simulation.PERSNROffset = str2num(string(h_PERSNROffset.String));
        simulation.DataQueueCycle = simulation.LoadCycle;
        simulation.handleTime = h_simu_time;
        simulation.handlenumPackets = h_simu_packets;
        simulation.ChannelModel = string(h_channel_popup.String{h_channel_popup.Value});           
        simulation.DelayProfile = string(h_tgax_DelayProfile.String{h_tgax_DelayProfile.Value});
        simulation.w2Scenario = string(h_w2_Scenario.String{h_w2_Scenario.Value});           
        simulation.w2PropCondition = string(h_w2_PropCondition.String{h_w2_PropCondition.Value});           
        simulation.RandomStream = string(h_RandomStream.String{h_RandomStream.Value}); 
        simulation.PHYType = string(h_PHY_type.String{h_PHY_type.Value});   
        simulation.ReportLevel = string(h_ReportLevel.String{h_ReportLevel.Value});           
        simulation.RSNRBase = string(h_RSNRBase.String{h_RSNRBase.Value});           
        simulation.logging = h_DoLog.Value;
        simulation.resettgax = h_reset_stream.Value;
        simulation.resetchannel = h_reset_stream.Value;
%         simulation.usetgax = h_use_tgax.Value;
        simulation.useawgn = h_use_awgn.Value;
        simulation.ConstAvgPow = h_const_pow.Value;
        simulation.DRC = h_LOOP_DRC.Value;
        simulation.NOINT = h_LOOP_NOINT.Value;
        simulation.TPOBSSPD = h_LOOP_TPOBSSPD.Value;
        simulation.ESTSINR = h_LOOP_ESTSINR.Value;
        simulation.BEAMFORMING = h_LOOP_BEAMFORMING.Value;
        
        simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
        simulation.LargeScaleFadingEffect = ...
            string(h_LargeScaleFadingEffect_tgax.String{h_LargeScaleFadingEffect_tgax.Value});
        simulation.WallPenetrationLoss = string(h_WallPenetrationLoss_tgax.String{h_WallPenetrationLoss_tgax.Value});            
        simulation.BPDistance = str2num(string(h_BP_distance.String));
        simulation.etaBeforeBPDistance = str2num(string(h_eta_bBP_distance.String));
        simulation.etaAfterBPDistance = str2num(string(h_eta_aBP_distance.String));
        simulation.WallPenetrationLossEta = str2num(string(h_WallPenetrationLoss.String));
        simulation.FloorPenetrationLossEta = str2num(string(h_FloorPenetrationLoss.String));

        str = h_LOOP_popup.String;
        val = h_LOOP_popup.Value;
        simulation.LoopPar = string(str{val});
        switch str{val}
            
            case 'PayloadLength'
               simulation.LoopVal = str2num(string(h_LOOP_PLLength.String));
             
            case 'MCS'
               simulation.LoopVal = str2num(string(h_LOOP_MCS.String));     
             
            case 'TransmitPower'
                simulation.LoopVal = str2num(string(h_LOOP_TP.String));
             
            case 'OBSS_PDLevel'
                simulation.LoopVal = str2num(string(h_LOOP_OBSSPD.String));
             
            case 'SNR'
                simulation.LoopVal = str2num(string(h_LOOP_SNR.String));
                
        end 

        % pass over to simulation
        [resultU, resultB] = sim_LOOP(all_bss, all_path_STA_DL, all_path_AP_DL, all_pathloss_STA_DL,...
            all_pathloss_AP_DL, all_path_STA_UL, all_path_AP_UL, all_pathloss_STA_UL,...
            all_pathloss_AP_UL, simulation, resultU, resultB, h_start_simu_pushbtn);

        case 'Other'    
        % do nothing right now
    
    end

    % Clear axes
    delete(h_axes_plot_left);
    delete(h_axes_plot_right);

    % Update popups to select plots
    % target BSS
    string_tmp = string(h_bss_vec_popup.String);
    h_plot_BSS_left.String = string_tmp;
    h_plot_BSS_right.String = string_tmp;
    h_plot_BSS_left.Value = 1;
    h_plot_BSS_right.Value = 1;

    % userplots
    numPlot = size(resultU,2);
    str_title = [];
    for idxPlot = 1:numPlot
        str_title = [str_title;string(resultU{1,idxPlot}.Title.String)];
    end
    h_plot_left.String = str_title;
    h_plot_left.Value = 1;
    h_plot_right.String = str_title;
    h_plot_right.Value = 1;

    % systemplots
    numPlot = size(resultB,2);
    str_title = [];
    for idxPlot = 1:numPlot
        str_title = [str_title;string(resultB{1,idxPlot}.Title.String)];
    end
    h_plot_AP_left.Value = 1;
    h_plot_AP_right.Value = 1;
    h_plot_AP_left.String = str_title;
    h_plot_AP_right.String = str_title;

    % save results for recovery
    % target bss, system report, bss report popup left & right
    plot_var.h_plot_BSS_left_String = h_plot_BSS_left.String;
    plot_var.h_plot_BSS_left_Value = h_plot_BSS_left.Value;
    plot_var.h_plot_AP_left_String = h_plot_AP_left.String;
    plot_var.h_plot_AP_left_Value = h_plot_AP_left.Value;
    plot_var.h_plot_left_String = h_plot_left.String;
    plot_var.h_plot_left_Value = h_plot_left.Value;
    plot_var.h_plot_BSS_right_String = h_plot_BSS_right.String;
    plot_var.h_plot_BSS_right_Value = h_plot_BSS_right.Value;
    plot_var.h_plot_AP_right_String = h_plot_AP_right.String;
    plot_var.h_plot_AP_right_Value = h_plot_AP_right.Value;
    plot_var.h_plot_right_String = h_plot_right.String;
    plot_var.h_plot_right_Value = h_plot_right.Value;
    
    % restore Start button text
    h_start_simu_pushbtn.String = {'Start'};
    
    %save key vars as mat file
    save('saveresults/simuResults.mat','resultB','resultU','plot_var');

end

% **********************************************************************************************************************
% Push Btn callback SIMU LOAD
function load_simu_pushbtn_Callback(source,eventdata)
    
% % %     % temp resolution to use old scenarios 
% % %     all_path_STA = {};
% % %     all_path_AP = {};
% % %     all_path_STA_UL = {};
% % %     all_path_AP_UL = {};    
    
    uiopen('load');

% % %     % temp resolution to use old scenarios 
% % %     all_path_STA_DL = all_path_STA;
% % %     all_path_AP_DL = all_path_AP;    

% % % % temp solution to use old scenarios
% % % numBSS = numel(all_bss);
% % % for idx = 1:numBSS
% % %     all_bss{idx}.ch = 1;
% % % end
% % % simulation.numCH = 3;
% % % simu_var.h_A2B_const_pow_Value = 0;


    % bss remove and path select popups
    h_bss_vec_popup.String = simu_var.h_bss_vec_popup_String;
    h_bss_vec_popup.Value = simu_var.h_bss_vec_popup_Value;
    h_path_ap_tx_popup.String = simu_var.h_path_ap_tx_popup_String;
    h_path_ap_tx_popup.Value = simu_var.h_path_ap_tx_popup_Value;
    h_path_ap_rx_popup.String = simu_var.h_path_bss_rx_popup_String;
    h_path_ap_rx_popup.Value = simu_var.h_path_bss_rx_popup_Value;
    
    % obstacle remove
    h_obstacle_vec_popup.String = simu_var.h_obstacle_vec_popup_String;
    h_obstacle_vec_popup.Value = simu_var.h_obstacle_vec_popup_Value;

    % plot spatial setup
    plot_all_bss_obstacles(all_bss, all_obstacles);

    % add simulation type string and selected value
    h_simu_popup.Value = simu_var.h_simu_popup_Value;

    % rest is dependend on simulation type
    str = h_simu_popup.String;
    val = h_simu_popup.Value;
    switch str{val}

        case 'CompareA2B'
        h_time.String = simu_var.h_A2B_time_String;
        h_LoadCycle.String = simu_var.h_A2B_LoadCycle_String;
        h_PERSNROffset.String = simu_var.h_A2B_PERSNROffset_String;
        h_channel_popup.Value = simu_var.h_A2B_ChannelModel_Value;
        h_tgax_DelayProfile.Value = simu_var.h_A2B_DelayProfile_Value;
        h_w2_Scenario.Value = simu_var.h_A2B_w2Scenario_Value;
        h_w2_PropCondition.Value = simu_var.h_A2B_w2PropCondition_Value;       
        h_RandomStream.Value = simu_var.h_A2B_RandomStream_Value;
        h_PHY_type.Value = simu_var.h_PHYType_Value;
        h_ReportLevel.Value = simu_var.h_A2B_ReportLevel_Value;
        h_RSNRBase.Value = simu_var.h_RSNRBase_Value;
        h_DoLog.Value = simu_var.h_A2B_DoLog_Value;
        h_reset_stream.Value = simu_var.h_A2B_reset_stream_Value;
%         h_use_tgax.Value = simu_var.h_A2B_use_tgax_Value;
        h_use_awgn.Value = simu_var.h_A2B_use_awgn_Value;
        h_const_pow.Value = simu_var.h_A2B_const_pow_Value;
        h_A2B_popupA.Value = simu_var.h_A2B_popupA_Value;
        h_A2B_popupB.Value = simu_var.h_A2B_popupB_Value;
        
        h_pathloss_popup.Value = simu_var.h_PathlossModel_Value;
        simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
        h_LargeScaleFadingEffect_tgax.Value = simu_var.h_LargeScaleFadingEffect_tgax_Value;
        h_WallPenetrationLoss_tgax.Value = simu_var.h_WallPenetrationLoss_tgax_Value;
        h_BP_distance.String = simu_var.h_BPDistance_String;
        h_eta_bBP_distance.String = simu_var.h_eta_bBPDistance_String;
        h_eta_aBP_distance.String = simu_var.h_eta_aBPDistance_String;
        h_WallPenetrationLoss.String = simu_var.h_WallPenetrationLoss_String;
        h_FloorPenetrationLoss.String = simu_var.h_FloorPenetrationLoss_String;      

        strA = h_A2B_popupA.String;
        valA = h_A2B_popupA.Value;
        switch strA{valA}

            case 'CSMA/CA'
            h_A2B_A1_DRC.Value = simu_var.h_A2B_A1_DRC_Value;
            h_A2B_A1_NOINT.Value = simu_var.h_A2B_A1_NOINT_Value;
            h_A2B_A1_ESTSINR.Value = simu_var.h_A2B_A1_ESTSINR_Value;
            h_A2B_A1_BEAMFORMING.Value = simu_var.h_A2B_A1_BEAMFORMING_Value;

            case 'CSMA/SDMSR'
            h_A2B_A8_VER.Value = simu_var.h_A2B_A8_VER_Value;
            h_A2B_A8_SchedAlloc.Value = simu_var.h_A2B_A8_SchedAlloc_Value;
            h_A2B_A8_MA.Value = simu_var.h_A2B_A8_MA_Value;

            case 'CSMA/SR'
            h_A2B_A9_VER.Value = simu_var.h_A2B_A9_VER_Value;
            h_A2B_A9_SchedAlloc.Value = simu_var.h_A2B_A9_SchedAlloc_Value;
            h_A2B_A9_MA.Value = simu_var.h_A2B_A9_MA_Value;

            case 'Other'
        
        end

        strB = h_A2B_popupB.String;
        valB = h_A2B_popupB.Value;
        switch strB{valB}

            case 'CSMA/CA'
            h_A2B_B1_DRC.Value = simu_var.h_A2B_B1_DRC_Value;
            h_A2B_B1_NOINT.Value = simu_var.h_A2B_B1_NOINT_Value;
            h_A2B_B1_ESTSINR.Value = simu_var.h_A2B_B1_ESTSINR_Value;
            h_A2B_B1_BEAMFORMING.Value = simu_var.h_A2B_B1_BEAMFORMING_Value;

            case 'CSMA/SDMSR'
            h_A2B_B8_VER.Value = simu_var.h_A2B_B8_VER_Value;
            h_A2B_B8_SchedAlloc.Value = simu_var.h_A2B_B8_SchedAlloc_Value;
            h_A2B_B8_MA.Value = simu_var.h_A2B_B8_MA_Value;

            case 'CSMA/SR'
            h_A2B_B9_VER.Value = simu_var.h_A2B_B9_VER_Value;
            h_A2B_B9_SchedAlloc.Value = simu_var.h_A2B_B9_SchedAlloc_Value;
            h_A2B_B9_MA.Value = simu_var.h_A2B_B9_MA_Value;

            case 'Other'

        end

        % trigger subpanel to update
        A2B_type_popupA_Callback(h_A2B_popupA,'');
        A2B_type_popupB_Callback(h_A2B_popupB,'');

        case 'LoopOver' 
        h_time.String = simu_var.h_LOOP_time_String;
        h_LoadCycle.String = simu_var.h_LOOP_LoadCycle_String;
        h_PERSNROffset.String = simu_var.h_LOOP_PERSNROffset_String;
        h_channel_popup.Value = simu_var.h_LOOP_ChannelModel_Value;
        h_tgax_DelayProfile.Value = simu_var.h_LOOP_DelayProfile_Value;
        h_w2_Scenario.Value = simu_var.h_LOOP_w2Scenario_Value;
        h_w2_PropCondition.Value = simu_var.h_LOOP_w2PropCondition_Value;       
        h_RandomStream.Value = simu_var.h_LOOP_RandomStream_Value;
        h_PHY_type.Value = simu_var.h_PHYType_Value;
        h_RSNRBase.Value = simu_var.h_RSNRBase_Value;
        h_ReportLevel.Value = simu_var.h_LOOP_ReportLevel_Value;
        h_DoLog.Value = simu_var.h_LOOP_DoLog_Value;
        h_reset_stream.Value = simu_var.h_LOOP_reset_stream_Value;
%         h_use_tgax.Value = simu_var.h_LOOP_use_tgax_Value;
        h_use_awgn.Value = simu_var.h_LOOP_use_awgn_Value;
        h_const_pow.Value = simu_var.h_LOOP_const_pow_Value;
        h_LOOP_DRC.Value = simu_var.h_LOOP_DRC_Value;
        h_LOOP_NOINT.Value = simu_var.h_LOOP_NOINT_Value;
        h_LOOP_TPOBSSPD.Value = simu_var.h_LOOP_TPOBSSPD_Value;
        h_LOOP_ESTSINR.Value = simu_var.h_LOOP_ESTSINR_Value;
        h_LOOP_BEAMFORMING.Value = simu_var.h_LOOP_BEAMFORMING_Value;
%         h_LOOP_popup.String = simu_var.h_LOOP_popup_String;
        h_LOOP_popup.Value = simu_var.h_LOOP_popup_Value;
        h_LOOP_PLLength.String = simu_var.h_LOOP_PLLength_String;
        h_LOOP_MCS.String = simu_var.h_LOOP_MCS_String;                     
        h_LOOP_TP.String = simu_var.h_LOOP_TP_String;
        h_LOOP_OBSSPD.String = simu_var.h_LOOP_OBSSPD_String;
        h_LOOP_SNR.String = simu_var.h_LOOP_SNR_String;
        
        h_pathloss_popup.Value = simu_var.h_PathlossModel_Value;
        simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
        h_LargeScaleFadingEffect_tgax.Value = simu_var.h_LargeScaleFadingEffect_tgax_Value;
        h_WallPenetrationLoss_tgax.Value = simu_var.h_WallPenetrationLoss_tgax_Value;
        h_BP_distance.String = simu_var.h_BPDistance_String;
        h_eta_bBP_distance.String = simu_var.h_eta_bBPDistance_String;
        h_eta_aBP_distance.String = simu_var.h_eta_aBPDistance_String;
        h_WallPenetrationLoss.String = simu_var.h_WallPenetrationLoss_String;
        h_FloorPenetrationLoss.String = simu_var.h_FloorPenetrationLoss_String;      

        case 'Other'
        h_simu_text.String = '';
        
    end
    
    % trigger callback to load panel
    simu_type_popup_Callback(h_simu_popup,'');
    pathloss_model_popup_Callback(h_pathloss_popup,'')
    channel_model_popup_Callback(h_channel_popup,'')
    
                % update all paths combinations
                all_path_STA_DL = combine_all_path_STA_DL(all_bss, all_obstacles, all_path_STA_DL);
                all_path_AP_DL = combine_all_path_AP_DL(all_bss, all_obstacles, all_path_AP_DL);
                all_path_STA_UL = combine_all_path_STA_UL(all_bss, all_obstacles, all_path_STA_UL);
                all_path_AP_UL = combine_all_path_AP_UL(all_bss, all_obstacles, all_path_AP_UL);

    
    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);
    
    % clear old plot results after load
    % target bss, system report, bss report popup left & right
    h_plot_BSS_left.String = ' ';
    h_plot_BSS_left.Value = 1;
    h_plot_AP_left.String = ' ';
    h_plot_AP_left.Value = 1;
    h_plot_left.String = ' ';
    h_plot_left.Value = 1;
    h_plot_BSS_right.String = ' ';
    h_plot_BSS_right.Value = 1;
    h_plot_AP_right.String = ' ';
    h_plot_AP_right.Value = 1;
    h_plot_right.String = ' ';
    h_plot_right.Value = 1;
    delete(h_axes_plot_left);
    delete(h_axes_plot_right);
    
    % update spatial view
    plot_all_bss_obstacles(all_bss, all_obstacles);
    
end

% **********************************************************************************************************************
% Push Btn callback SIMU SAVE
function save_simu_pushbtn_Callback(source,eventdata)
    
    % global variable has to be used once to get updated
    simulation.timestamp = datestr(now, 0);
    
    % bss remove and path select popups
    simu_var.h_bss_vec_popup_String = h_bss_vec_popup.String;
    simu_var.h_bss_vec_popup_Value = h_bss_vec_popup.Value;
    simu_var.h_path_ap_tx_popup_String = h_path_ap_tx_popup.String;
    simu_var.h_path_ap_tx_popup_Value = h_path_ap_tx_popup.Value;
    simu_var.h_path_bss_rx_popup_String = h_path_ap_rx_popup.String;
    simu_var.h_path_bss_rx_popup_Value = h_path_ap_rx_popup.Value;
    
    % obstacle remove
    simu_var.h_obstacle_vec_popup_String = h_obstacle_vec_popup.String;
    simu_var.h_obstacle_vec_popup_Value = h_obstacle_vec_popup.Value;

    % add simulation type string and selected value
    simu_var.h_simu_popup_Value = h_simu_popup.Value;     
    
    % rest is dependend on simulation type
    str = h_simu_popup.String;
    val = h_simu_popup.Value;
    switch str{val}

        case 'CompareA2B'
        simu_var.h_A2B_time_String = h_time.String;
        simu_var.h_A2B_LoadCycle_String = h_LoadCycle.String;
        simu_var.h_A2B_PERSNROffset_String = h_PERSNROffset.String;        
        simu_var.h_A2B_ChannelModel_Value = h_channel_popup.Value;
        simu_var.h_A2B_DelayProfile_Value = h_tgax_DelayProfile.Value;
        simu_var.h_A2B_w2Scenario_Value = h_w2_Scenario.Value;
        simu_var.h_A2B_w2PropCondition_Value = h_w2_PropCondition.Value;        
        simu_var.h_A2B_RandomStream_Value = h_RandomStream.Value;
        simu_var.h_PHYType_Value = h_PHY_type.Value;
        simu_var.h_A2B_ReportLevel_Value = h_ReportLevel.Value;
        simu_var.h_RSNRBase_Value = h_RSNRBase.Value;
        simu_var.h_A2B_DoLog_Value = h_DoLog.Value;
        simu_var.h_A2B_reset_stream_Value = h_reset_stream.Value;
%         simu_var.h_A2B_use_tgax_Value = h_use_tgax.Value;
        simu_var.h_A2B_use_awgn_Value = h_use_awgn.Value;
        simu_var.h_A2B_const_pow_Value = h_const_pow.Value;
        simu_var.h_A2B_popupA_Value = h_A2B_popupA.Value;
        simu_var.h_A2B_popupB_Value = h_A2B_popupB.Value;
        
        simu_var.h_PathlossModel_Value = h_pathloss_popup.Value;
        simu_var.h_LargeScaleFadingEffect_tgax_Value = h_LargeScaleFadingEffect_tgax.Value;
        simu_var.h_WallPenetrationLoss_tgax_Value = h_WallPenetrationLoss_tgax.Value;
        simu_var.h_BPDistance_String = h_BP_distance.String;
        simu_var.h_eta_bBPDistance_String = h_eta_bBP_distance.String;
        simu_var.h_eta_aBPDistance_String = h_eta_aBP_distance.String;
        simu_var.h_WallPenetrationLoss_String = h_WallPenetrationLoss.String;
        simu_var.h_FloorPenetrationLoss_String = h_FloorPenetrationLoss.String;     

        strA = h_A2B_popupA.String;
        valA = h_A2B_popupA.Value;
        switch strA{valA}

            case 'CSMA/CA'
                simu_var.h_A2B_A1_DRC_Value = h_A2B_A1_DRC.Value;
                simu_var.h_A2B_A1_NOINT_Value = h_A2B_A1_NOINT.Value;
                simu_var.h_A2B_A1_ESTSINR_Value = h_A2B_A1_ESTSINR.Value;
                simu_var.h_A2B_A1_BEAMFORMING_Value = h_A2B_A1_BEAMFORMING.Value;

            case 'CSMA/SDMSR'
                simu_var.h_A2B_A8_VER_Value = h_A2B_A8_VER.Value;
                simu_var.h_A2B_A8_SchedAlloc_Value = h_A2B_A8_SchedAlloc.Value;
                simu_var.h_A2B_A8_MA_Value = h_A2B_A8_MA.Value;

            case 'CSMA/SR'
                simu_var.h_A2B_A9_VER_Value = h_A2B_A9_VER.Value;
                simu_var.h_A2B_A9_SchedAlloc_Value = h_A2B_A9_SchedAlloc.Value;
                simu_var.h_A2B_A9_MA_Value = h_A2B_A9_MA.Value;

            case 'Other'

        end

        strB = h_A2B_popupB.String;
        valB = h_A2B_popupB.Value;
        switch strB{valB}

            case 'CSMA/CA'
                simu_var.h_A2B_B1_DRC_Value = h_A2B_B1_DRC.Value;
                simu_var.h_A2B_B1_NOINT_Value = h_A2B_B1_NOINT.Value;  
                simu_var.h_A2B_B1_ESTSINR_Value = h_A2B_B1_ESTSINR.Value;  
                simu_var.h_A2B_B1_BEAMFORMING_Value = h_A2B_B1_BEAMFORMING.Value;  

            case 'CSMA/SDMSR'
                simu_var.h_A2B_B8_VER_Value = h_A2B_B8_VER.Value;
                simu_var.h_A2B_B8_SchedAlloc_Value = h_A2B_B8_SchedAlloc.Value;
                simu_var.h_A2B_B8_MA_Value = h_A2B_B8_MA.Value;

            case 'CSMA/SR'
                simu_var.h_A2B_B9_VER_Value = h_A2B_B9_VER.Value;
                simu_var.h_A2B_B9_SchedAlloc_Value = h_A2B_B9_SchedAlloc.Value;
                simu_var.h_A2B_B9_MA_Value = h_A2B_B9_MA.Value;

            case 'Other'

        end

        case 'LoopOver'
            simu_var.h_LOOP_time_String = h_time.String;
            simu_var.h_LOOP_LoadCycle_String = h_LoadCycle.String;
            simu_var.h_LOOP_PERSNROffset_String = h_PERSNROffset.String;
            simu_var.h_LOOP_ChannelModel_Value = h_channel_popup.Value;
            simu_var.h_LOOP_DelayProfile_Value = h_tgax_DelayProfile.Value;
            simu_var.h_LOOP_w2Scenario_Value = h_w2_Scenario.Value;
            simu_var.h_LOOP_w2PropCondition_Value = h_w2_PropCondition.Value;          
            simu_var.h_LOOP_RandomStream_Value = h_RandomStream.Value;
            simu_var.h_PHYType_Value = h_PHY_type.Value;
            simu_var.h_LOOP_ReportLevel_Value = h_ReportLevel.Value;
            simu_var.h_RSNRBase_Value = h_RSNRBase.Value;
            simu_var.h_LOOP_DoLog_Value = h_DoLog.Value;
            simu_var.h_LOOP_reset_stream_Value = h_reset_stream.Value;
%             simu_var.h_LOOP_use_tgax_Value = h_use_tgax.Value;
            simu_var.h_LOOP_use_awgn_Value = h_use_awgn.Value;
            simu_var.h_LOOP_const_pow_Value = h_const_pow.Value;
            simu_var.h_LOOP_DRC_Value = h_LOOP_DRC.Value;
            simu_var.h_LOOP_NOINT_Value = h_LOOP_NOINT.Value;
            simu_var.h_LOOP_TPOBSSPD_Value = h_LOOP_TPOBSSPD.Value;
            simu_var.h_LOOP_ESTSINR_Value = h_LOOP_ESTSINR.Value;
            simu_var.h_LOOP_BEAMFORMING_Value = h_LOOP_BEAMFORMING.Value;
            simu_var.h_LOOP_popup_Value = h_LOOP_popup.Value;
            simu_var.h_LOOP_PLLength_String = h_LOOP_PLLength.String;
            simu_var.h_LOOP_MCS_String = h_LOOP_MCS.String;                     
            simu_var.h_LOOP_TP_String = h_LOOP_TP.String;
            simu_var.h_LOOP_OBSSPD_String = h_LOOP_OBSSPD.String;   
            simu_var.h_LOOP_SNR_String = h_LOOP_SNR.String;   
            
            simu_var.h_PathlossModel_Value = h_pathloss_popup.Value;
            simu_var.h_LargeScaleFadingEffect_tgax_Value = h_LargeScaleFadingEffect_tgax.Value;
            simu_var.h_WallPenetrationLoss_tgax_Value = h_WallPenetrationLoss_tgax.Value;
            simu_var.h_BPDistance_String = h_BP_distance.String;
            simu_var.h_eta_bBPDistance_String = h_eta_bBP_distance.String;
            simu_var.h_eta_aBPDistance_String = h_eta_aBP_distance.String;
            simu_var.h_WallPenetrationLoss_String = h_WallPenetrationLoss.String;
            simu_var.h_FloorPenetrationLoss_String = h_FloorPenetrationLoss.String;     

        case 'Other'
    
    end          
    
    %save key vars as mat file with GUI support
    uisave({'all_bss','all_obstacles','all_path_STA_DL','all_path_AP_DL','all_path_STA_UL','all_path_AP_UL',...
        'simulation','simu_var'},'/scenarios/scenario.mat');
    
end

% **********************************************************************************************************************
%  Pop-up menu callback PLOT SELECT LEFT
function select_plot_left_Callback(source,eventdata)
    
    bss = h_plot_BSS_left.Value;
    val = source.Value;
    delete(h_axes_plot_left);
    h_axes_plot_left = copyobj(resultU{bss,val},h_pan_plot);
    h_axes_plot_left.Parent = h_pan_plot;
    h_axes_plot_left.Position = pos_plot_left;
    legend(h_axes_plot_left);
    h_axes_plot_left.Toolbar.Visible = 'On';

end

% **********************************************************************************************************************
%  Pop-up menu callback PLOT SELECT RIGHT
function select_plot_right_Callback(source,eventdata) 
    
    bss = h_plot_BSS_right.Value;
    val = source.Value;
    delete(h_axes_plot_right);
    h_axes_plot_right = copyobj(resultU{bss,val},h_pan_plot);
    h_axes_plot_right.Parent = h_pan_plot;
    h_axes_plot_right.Position = pos_plot_right;
    legend(h_axes_plot_right);
    h_axes_plot_right.Toolbar.Visible = 'On';
    
end

% **********************************************************************************************************************
%  Pop-up menu callback PLOT SELECT AP LEFT
function select_AP_plot_left_Callback(source,eventdata)
    
    val = source.Value;
    delete(h_axes_plot_left);
    h_axes_plot_left = copyobj(resultB{val},h_pan_plot);
    h_axes_plot_left.Parent = h_pan_plot;
    h_axes_plot_left.Position = pos_plot_left;
    legend(h_axes_plot_left);
    h_axes_plot_left.Toolbar.Visible = 'On';

end

% **********************************************************************************************************************
%  Pop-up menu callback PLOT SELECT AP RIGHT
function select_AP_plot_right_Callback(source,eventdata) 
    
    val = source.Value;
    delete(h_axes_plot_right);
    h_axes_plot_right = copyobj(resultB{val},h_pan_plot);
    h_axes_plot_right.Parent = h_pan_plot;
    h_axes_plot_right.Position = pos_plot_right;
    legend(h_axes_plot_right);
    h_axes_plot_right.Toolbar.Visible = 'On';
    
end

% **********************************************************************************************************************
%  Pop-up menu callback BSS SELECT LEFT
function select_bss_plot_left_Callback(source,eventdata)
    
    val = source.Value;
    numPlot = size(resultU,2);
    str_title = [];
    for idxPlot = 1:numPlot
        str_title = [str_title;string(resultU{val,idxPlot}.Title.String)];
    end
    h_plot_left.Value = 1;
    h_plot_left.String = str_title;

end

% **********************************************************************************************************************
%  Pop-up menu callback BSS SELECT RIGHT
function select_bss_plot_right_Callback(source,eventdata)
    
    val = source.Value;
    numPlot = size(resultU,2);
    str_title = [];
    for idxPlot = 1:numPlot
        str_title = [str_title;string(resultU{val,idxPlot}.Title.String)];
    end
    h_plot_right.Value = 1;
    h_plot_right.String = str_title;

end

% **********************************************************************************************************************
% Push Btn callback PLOT LOAD
function load_plot_pushbtn_Callback(source,eventdata)
    
    uiopen('load');
    delete(h_axes_plot_left);
    delete(h_axes_plot_right);
    
    % target bss, system report, bss report popup left & right
    h_plot_BSS_left.String = plot_var.h_plot_BSS_left_String;
    h_plot_BSS_left.Value = plot_var.h_plot_BSS_left_Value;
    h_plot_AP_left.String = plot_var.h_plot_AP_left_String;
    h_plot_AP_left.Value = plot_var.h_plot_AP_left_Value;
    h_plot_left.String = plot_var.h_plot_left_String;
    h_plot_left.Value = plot_var.h_plot_left_Value;
    h_plot_BSS_right.String = plot_var.h_plot_BSS_right_String;
    h_plot_BSS_right.Value = plot_var.h_plot_BSS_right_Value;
    h_plot_AP_right.String = plot_var.h_plot_AP_right_String;
    h_plot_AP_right.Value = plot_var.h_plot_AP_right_Value;
    h_plot_right.String = plot_var.h_plot_right_String;
    h_plot_right.Value = plot_var.h_plot_right_Value;

end

% **********************************************************************************************************************
% Push Btn callback PLOT SAVE
function save_plot_pushbtn_Callback(source,eventdata)

    % target bss, system report, bss report popup left & right
    plot_var.h_plot_BSS_left_String = h_plot_BSS_left.String;
    plot_var.h_plot_BSS_left_Value = h_plot_BSS_left.Value;
    plot_var.h_plot_AP_left_String = h_plot_AP_left.String;
    plot_var.h_plot_AP_left_Value = h_plot_AP_left.Value;
    plot_var.h_plot_left_String = h_plot_left.String;
    plot_var.h_plot_left_Value = h_plot_left.Value;
    plot_var.h_plot_BSS_right_String = h_plot_BSS_right.String;
    plot_var.h_plot_BSS_right_Value = h_plot_BSS_right.Value;
    plot_var.h_plot_AP_right_String = h_plot_AP_right.String;
    plot_var.h_plot_AP_right_Value = h_plot_AP_right.Value;
    plot_var.h_plot_right_String = h_plot_right.String;
    plot_var.h_plot_right_Value = h_plot_right.Value;
    
    %save key vars as mat file with GUI support
    uisave({'resultB','resultU','plot_var'},'/reports/report.mat');

end

% **********************************************************************************************************************
% Push Btn callback PUSH FIGURES
function push_fig_pushbtn_Callback(source,eventdata)
    
    % spatial setup plot
    fh = figure();   
    copyobj(h_axes_space,fh);

    % BSS plots
    numBSS = numel(all_bss);
    numPlot = size(resultU,2);
    for idxBSS = 1:numBSS
        for idxPlot = 1:numPlot
            fh = figure();
            copyobj(resultU{idxBSS,idxPlot},fh);
            legend();
            
        end
    end

    % AP and System plots
    numPlot = size(resultB,2);
    for idxPlot = 1:numPlot
        fh = figure();
        copyobj(resultB{idxPlot},fh);
        legend();
    end          

end

% **********************************************************************************************************************
% Push Btn multiple callback UPDATE PATHLOSS
function update_Pathloss_Callback(source,eventdata)

    simulation.ChannelModel = string(h_channel_popup.String{h_channel_popup.Value});    
    simulation.DelayProfile = string(h_tgax_DelayProfile.String{h_tgax_DelayProfile.Value});    
    simulation.w2Scenario = string(h_w2_Scenario.String{h_w2_Scenario.Value});           
    simulation.w2PropCondition = string(h_w2_PropCondition.String{h_w2_PropCondition.Value});           
    simulation.PathlossModel = string(h_pathloss_popup.String{h_pathloss_popup.Value});
    simulation.LargeScaleFadingEffect = ...
        string(h_LargeScaleFadingEffect_tgax.String{h_LargeScaleFadingEffect_tgax.Value});
    simulation.WallPenetrationLoss = string(h_WallPenetrationLoss_tgax.String{h_WallPenetrationLoss_tgax.Value});            
    simulation.BPDistance = str2num(string(h_BP_distance.String));
    simulation.etaBeforeBPDistance = str2num(string(h_eta_bBP_distance.String));
    simulation.etaAfterBPDistance = str2num(string(h_eta_aBP_distance.String));
    simulation.WallPenetrationLossEta = str2num(string(h_WallPenetrationLoss.String));
    simulation.FloorPenetrationLossEta = str2num(string(h_FloorPenetrationLoss.String));
    
    % build pathloss for all AP STA & AP AP combinations; also possible via info(tgax).pathloss
    all_pathloss_STA_DL = all_pathloss_AP_STA(all_bss, all_path_STA_DL, simulation);
    all_pathloss_AP_DL = all_pathloss_AP_AP(all_bss, all_path_AP_DL, simulation);
    all_pathloss_STA_UL = all_pathloss_STA_STA(all_bss, all_path_STA_UL, simulation);
    all_pathloss_AP_UL = all_pathloss_STA_AP(all_bss, all_path_AP_UL, simulation);
    
    % clear path line and values
    clearLineValues();

end


% **********************************************************************************************************************
% OTHER FUNCTIONS
% **********************************************************************************************************************

% **********************************************************************************************************************
% function to plot configuration of all bsss & obstacles in space figure
function plot_all_bss_obstacles(cell_bss, cell_obstacles)
    
    % make space figure current axes, clear the content
    axes(h_axes_space);         
    cla(h_axes_space,'reset');
    
    h_axes_space.Toolbar.Visible = 'On';

    numBSS = numel(cell_bss);
    numObstacles = numel(cell_obstacles);

    % create color map, also for more than 6
    map = [0 0 1; 1 0 0; 0 0 0; 1 0 1; 0 1 1; 0 1 0];
    if numBSS > 6 
        map = repmat(map,1+floor((numBSS-1)/6),1);
    end

    for idx = 1:numBSS

        % plot AP
        x_tmp = cell_bss{idx}.AP_pos(1);
        y_tmp = cell_bss{idx}.AP_pos(2);
        z_tmp = cell_bss{idx}.AP_pos(3);
        h_AP_space{idx} = scatter3(x_tmp, y_tmp, z_tmp,50,map(idx,:),'h');

        % plot STAs
        hold on;
        x_tmp = cell_bss{idx}.STAs_pos(:,1);
        y_tmp = cell_bss{idx}.STAs_pos(:,2);
        z_tmp = cell_bss{idx}.STAs_pos(:,3);
        h_STA_space{idx} = scatter3(x_tmp, y_tmp, z_tmp,50,map(idx,:),'+');

    end
    
    % plot ULA in case of WINNER II channel model
    lambda = physconst('LightSpeed')/simulation.CarrierFrequency;
    vl = lambda * 3;
    str = h_channel_popup.String;
    val = h_channel_popup.Value;
    switch str{val}
        
        case 'WINNER II'
            for idx_BSS = 1:numBSS
                % plot AP ULA
                x_tmp = cell_bss{idx_BSS}.AP_pos(1);
                y_tmp = cell_bss{idx_BSS}.AP_pos(2);
                z_tmp = cell_bss{idx_BSS}.AP_pos(3);
                num_ant = cell_bss{idx_BSS}.num_tx;

                switch num_ant
                    case 1
                        h_AP_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                    case 2
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                    case 3
                        h_AP_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                    case 4
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                    case 5
                        h_AP_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+2*vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-2*vl, y_tmp, z_tmp,'g.');
                    case 6
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*5/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*5/2, y_tmp, z_tmp,'g.');
                    case 7
                        h_AP_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+2*vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-2*vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+3*vl, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-3*vl, y_tmp, z_tmp,'g.');
                    case 8
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*5/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*5/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp+vl*7/2, y_tmp, z_tmp,'g.');
                        h_AP_ULA_space{idx} = plot3(x_tmp-vl*7/2, y_tmp, z_tmp,'g.');
                end               

                numSTAs = size(cell_bss{idx_BSS}.STAs_pos,1);
                for idx_STA = 1:numSTAs
                    % plot STA ULA
                    x_tmp = cell_bss{idx_BSS}.STAs_pos(idx_STA,1);
                    y_tmp = cell_bss{idx_BSS}.STAs_pos(idx_STA,2);
                    z_tmp = cell_bss{idx_BSS}.STAs_pos(idx_STA,3);
                    num_ant = cell_bss{idx_BSS}.num_rx;

                    switch num_ant
                        case 1
                            h_STA_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                        case 2
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                        case 3
                            h_STA_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                        case 4
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                        case 5
                            h_STA_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+2*vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-2*vl, y_tmp, z_tmp,'g.');
                        case 6
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*5/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*5/2, y_tmp, z_tmp,'g.');
                        case 7
                            h_STA_ULA_space{idx} = plot3(x_tmp, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+2*vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-2*vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+3*vl, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-3*vl, y_tmp, z_tmp,'g.');
                        case 8
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*1/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*3/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*3/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*5/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*5/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp+vl*7/2, y_tmp, z_tmp,'g.');
                            h_STA_ULA_space{idx} = plot3(x_tmp-vl*7/2, y_tmp, z_tmp,'g.');
                    end               
                    
                end
            end
    end  
        
    for idx = 1:numObstacles

        % plot obstacle
        hold on;
        x_tmp = cell_obstacles{idx}.pos(:,1);
        y_tmp = cell_obstacles{idx}.pos(:,2);
        z_tmp = cell_obstacles{idx}.pos(:,3);
        if strcmp(string(cell_obstacles{idx}.type),'Wall')
            h_OB_space{idx} = patch(x_tmp, y_tmp, z_tmp,'b','FaceAlpha',.02);            
        elseif strcmp(string(cell_obstacles{idx}.type),'Floor')
            h_OB_space{idx} = patch(x_tmp, y_tmp, z_tmp,'b','FaceAlpha',.05);
        end
        view(3);

    end

    hold off;

end

% **********************************************************************************************************************
% function to combine bsss & obstacles to paths STA
function [cell_paths] = combine_all_path_STA_DL(cell_bss, cell_obstacles, cell_paths)
    
    cell_paths = {};
    numBSS = numel(cell_bss);
    numObstacles = numel(cell_obstacles);

    % for every AP to STA find the norm(A - B) to give the distance
    % and also check if there are floors or walls between LOS AP to STA
    for idx_AP = 1:numBSS %every AP
        for idx_BSS = 1:numBSS %every LINK with STAs
            numSTAs = size(cell_bss{idx_BSS}.STAs_pos,1);
            for idx_STA = 1:numSTAs %every STA from LINK
                
                P0 = cell_bss{idx_AP}.AP_pos;
                P1 = cell_bss{idx_BSS}.STAs_pos(idx_STA,:);
                cell_paths{idx_AP,idx_BSS,idx_STA}.distance = norm(P0-P1);
                
                % check obstacles
                wall_cnt = 0;
                floor_cnt = 0;
                for idx_obstacles = 1:numObstacles
                    
                    % use 3 points from obstacle to check collision of path with plane
                    PA = cell_obstacles{idx_obstacles}.pos(1,:);
                    PB = cell_obstacles{idx_obstacles}.pos(2,:);
                    PC = cell_obstacles{idx_obstacles}.pos(3,:);
                    PD = cell_obstacles{idx_obstacles}.pos(4,:);

                    % switch to needed parameter form
                    PAB = PB - PA;
                    PAD = PD - PA;
                    n = cross(PAB,PAD)/sqrt(dot(cross(PAB,PAD),cross(PAB,PAD)));

                    % check collision, always using plane not rectangle
                    [I,check]=plane_line_intersect(n,PA,P0,P1);

                    if check == 1   % 1 means unique collision point
                        
                        % check if point I lies within reactangle of obstacle
                        % project vector P0P to vectors PAB and PAD
                        P0P = I - PA;
                        Q1 = (dot(P0P,PAB)/norm(PAB)^2)*PAB;
                        Q2 = (dot(P0P,PAD)/norm(PAD)^2)*PAD;
                        % calculate norms, but save oposite direction:
                        Dir1=any(Q1<0);
                        Dir2=any(Q2<0);
                        NQ1 = norm(Q1);
                        NQ2 = norm(Q2);
                        NPAB = norm(PAB);
                        NPAD = norm(PAD);
                        % check condition for within rectangle
                        if ~Dir1 && NQ1 <= NPAB && ~Dir2 && NQ2 <= NPAD
                            if strcmp(string(cell_obstacles{idx_obstacles}.type),'Wall')
                                wall_cnt = wall_cnt + 1;
                            elseif strcmp(string(cell_obstacles{idx_obstacles}.type),'Floor')
                                floor_cnt = floor_cnt + 1;
                            end
                        end
                    end 
                    
                end
                cell_paths{idx_AP,idx_BSS,idx_STA}.floors = floor_cnt;
                cell_paths{idx_AP,idx_BSS,idx_STA}.walls = wall_cnt;
                
            end
        end
    end       
end

% **********************************************************************************************************************
% function to combine bsss & obstacles to paths STA UL
function [cell_paths] = combine_all_path_STA_UL(cell_bss, cell_obstacles, cell_paths)
    
    cell_paths = {};
    numBSS = numel(cell_bss);
    numObstacles = numel(cell_obstacles);

    % for every AP / STA to STA find the norm(A - B) to give the distance
    % there is no problem to check an STA to itself
    % and also check if there are floors or walls between LOS AP / STA to STA
    for idx_AP = 1:numBSS %every AP
        
        numTXSTAs = size(cell_bss{idx_AP}.STAs_pos,1);
        for idx_TXSTA = 1:numTXSTAs %every STA from AP
        
            for idx_BSS = 1:numBSS %every LINK with STAs
                
                numSTAs = size(cell_bss{idx_BSS}.STAs_pos,1);
                for idx_STA = 1:numSTAs %every STA from LINK

%                     P0 = cell_bss{idx_AP}.AP_pos;
                    P0 = cell_bss{idx_AP}.STAs_pos(idx_TXSTA,:);
                    P1 = cell_bss{idx_BSS}.STAs_pos(idx_STA,:);
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS,idx_STA}.distance = norm(P0-P1);

                    % check obstacles
                    wall_cnt = 0;
                    floor_cnt = 0;
                    for idx_obstacles = 1:numObstacles

                        % use 3 points from obstacle to check collision of path with plane
                        PA = cell_obstacles{idx_obstacles}.pos(1,:);
                        PB = cell_obstacles{idx_obstacles}.pos(2,:);
                        PC = cell_obstacles{idx_obstacles}.pos(3,:);
                        PD = cell_obstacles{idx_obstacles}.pos(4,:);

                        % switch to needed parameter form
                        PAB = PB - PA;
                        PAD = PD - PA;
                        n = cross(PAB,PAD)/sqrt(dot(cross(PAB,PAD),cross(PAB,PAD)));

                        % check collision, always using plane not rectangle
                        [I,check]=plane_line_intersect(n,PA,P0,P1);

                        if check == 1   % 1 means unique collision point
                            
                            % check if point I lies within reactangle of obstacle
                            % project vector P0P to vectors PAB and PAD
                            P0P = I - PA;
                            Q1 = (dot(P0P,PAB)/norm(PAB)^2)*PAB;
                            Q2 = (dot(P0P,PAD)/norm(PAD)^2)*PAD;
                            % calculate norms, but save oposite direction:
                            Dir1=any(Q1<0);
                            Dir2=any(Q2<0);
                            NQ1 = norm(Q1);
                            NQ2 = norm(Q2);
                            NPAB = norm(PAB);
                            NPAD = norm(PAD);
                            % check condition for within rectangle
                            if ~Dir1 && NQ1 <= NPAB && ~Dir2 && NQ2 <= NPAD
                                if strcmp(string(cell_obstacles{idx_obstacles}.type),'Wall')
                                    wall_cnt = wall_cnt + 1;
                                elseif strcmp(string(cell_obstacles{idx_obstacles}.type),'Floor')
                                    floor_cnt = floor_cnt + 1;
                                end
                            end
                        end 

                    end
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS,idx_STA}.floors = floor_cnt;
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS,idx_STA}.walls = wall_cnt;

                end
            end
        
        end    
        
    end       
end

% **********************************************************************************************************************
% function to combine bsss & obstacles to paths AP
function [cell_paths] = combine_all_path_AP_DL(cell_bss, cell_obstacles, cell_paths)
    
    cell_paths = {};
    numBSS = numel(cell_bss);
    numObstacles = numel(cell_obstacles);

    % for every AP to AP find the norm(A - B) to give the distance
    % and also check if there are floors or walls between LOS AP to AP
    for idx_AP = 1:numBSS %every AP
        for idx_BSS = 1:numBSS %every other LINK / AP
            
            P0 = cell_bss{idx_AP}.AP_pos;
            P1 = cell_bss{idx_BSS}.AP_pos;
            cell_paths{idx_AP,idx_BSS}.distance = norm(P0-P1);
            
            % check obstacles
            wall_cnt = 0;
            floor_cnt = 0;
            for idx_obstacles = 1:numObstacles
                
                % use 3 points from obstacle to check collision of path with plane
                PA = cell_obstacles{idx_obstacles}.pos(1,:);
                PB = cell_obstacles{idx_obstacles}.pos(2,:);
                PC = cell_obstacles{idx_obstacles}.pos(3,:);
                PD = cell_obstacles{idx_obstacles}.pos(4,:);

                % switch to needed parameter form
                PAB = PB - PA;
                PAD = PD - PA;
                n = cross(PAB,PAD)/sqrt(dot(cross(PAB,PAD),cross(PAB,PAD)));

                % check collision, always using plane not rectangle
                [I,check] = plane_line_intersect(n,PA,P0,P1);
                if check == 1   % 1 means unique collision point
                    % check if point I lies within reactangle of obstacle
                    % project vector P0P to vectors PAB and PAD
                    P0P = I - PA;
                    Q1 = (dot(P0P,PAB)/norm(PAB)^2)*PAB;
                    Q2 = (dot(P0P,PAD)/norm(PAD)^2)*PAD;
                    % calculate norms, but save oposite direction:
                    Dir1=any(Q1<0);
                    Dir2=any(Q2<0);
                    NQ1 = norm(Q1);
                    NQ2 = norm(Q2);
                    NPAB = norm(PAB);
                    NPAD = norm(PAD);
                    % check condition for within rectangle
                    if ~Dir1 && NQ1 <= NPAB && ~Dir2 && NQ2 <= NPAD
                        if strcmp(string(cell_obstacles{idx_obstacles}.type),'Wall')
                            wall_cnt = wall_cnt + 1;
                        elseif strcmp(string(cell_obstacles{idx_obstacles}.type),'Floor')
                            floor_cnt = floor_cnt + 1;
                        end
                    end
                end
                
            end
            cell_paths{idx_AP,idx_BSS}.floors = floor_cnt;
            cell_paths{idx_AP,idx_BSS}.walls = wall_cnt;
        end
    end       

end

% **********************************************************************************************************************
% function to combine bsss & obstacles to paths AP
function [cell_paths] = combine_all_path_AP_UL(cell_bss, cell_obstacles, cell_paths)
    
    cell_paths = {};
    numBSS = numel(cell_bss);
    numObstacles = numel(cell_obstacles);

    % for every AP / STA to AP find the norm(A - B) to give the distance
    % and also check if there are floors or walls between LOS AP / STA to AP
    for idx_AP = 1:numBSS %every AP
        
        numTXSTAs = size(cell_bss{idx_AP}.STAs_pos,1);
        for idx_TXSTA = 1:numTXSTAs %every STA from AP
        
            for idx_BSS = 1:numBSS %every LINK with STAs
                
                    P0 = cell_bss{idx_AP}.STAs_pos(idx_TXSTA,:);
                    P1 = cell_bss{idx_BSS}.AP_pos;
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS}.distance = norm(P0-P1);

                    % check obstacles
                    wall_cnt = 0;
                    floor_cnt = 0;
                    for idx_obstacles = 1:numObstacles

                        % use 3 points from obstacle to check collision of path with plane
                        PA = cell_obstacles{idx_obstacles}.pos(1,:);
                        PB = cell_obstacles{idx_obstacles}.pos(2,:);
                        PC = cell_obstacles{idx_obstacles}.pos(3,:);
                        PD = cell_obstacles{idx_obstacles}.pos(4,:);

                        % switch to needed parameter form
                        PAB = PB - PA;
                        PAD = PD - PA;
                        n = cross(PAB,PAD)/sqrt(dot(cross(PAB,PAD),cross(PAB,PAD)));

                        % check collision, always using plane not rectangle
                        [I,check]=plane_line_intersect(n,PA,P0,P1);

                        if check == 1   % 1 means unique collision point
                            % check if point I lies within reactangle of obstacle
                            % project vector P0P to vectors PAB and PAD
                            P0P = I - PA;
                            Q1 = (dot(P0P,PAB)/norm(PAB)^2)*PAB;
                            Q2 = (dot(P0P,PAD)/norm(PAD)^2)*PAD;
                            % calculate norms, but save oposite direction:
                            Dir1=any(Q1<0);
                            Dir2=any(Q2<0);
                            NQ1 = norm(Q1);
                            NQ2 = norm(Q2);
                            NPAB = norm(PAB);
                            NPAD = norm(PAD);
                            % check condition for within rectangle
                            if ~Dir1 && NQ1 <= NPAB && ~Dir2 && NQ2 <= NPAD                            
                                if strcmp(string(cell_obstacles{idx_obstacles}.type),'Wall')
                                    wall_cnt = wall_cnt + 1;
                                elseif strcmp(string(cell_obstacles{idx_obstacles}.type),'Floor')
                                    floor_cnt = floor_cnt + 1;
                                end
                            end
                        end 

                    end
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS}.floors = floor_cnt;
                    cell_paths{idx_AP,idx_TXSTA,idx_BSS}.walls = wall_cnt;

            end
        
        end    
        
    end           

end

% **********************************************************************************************************************
% this function calculates all PL between APs and APs
function [all_pathloss] = all_pathloss_AP_AP(all_bss, all_paths, simulation)
numBSS = numel(all_bss);
all_pathloss= [];

% for every AP to AP find the pathloss along given simulation model
    for idx_AP = 1:numBSS %every AP
        for idx_LINK = 1:numBSS %every other AP
            
            switch simulation.PathlossModel
            
                case 'TGax'            
                    all_pathloss{idx_AP,idx_LINK} = pathloss_tgax_AP(idx_AP,idx_LINK,all_paths,simulation);

                case 'EtaPowerLaw'            
                    all_pathloss{idx_AP,idx_LINK} = pathloss_etaPL_AP(idx_AP,idx_LINK,all_paths,simulation);

                case 'Other'            
                    all_pathloss{idx_AP,idx_LINK} = pathloss_etaPL_AP(idx_AP,idx_LINK,all_paths,simulation);
                    
            end
            
        end
    end
end

% **********************************************************************************************************************
% this function calculates all PL between STAs and APs
function [all_pathloss] = all_pathloss_STA_AP(all_bss, all_paths, simulation)
numBSS = numel(all_bss);
all_pathloss= [];

% for every STA to AP find the pathloss along given simulation model
    for idx_AP = 1:numBSS %every AP
        
        numTXSTAs = size(all_bss{idx_AP}.STAs_pos,1); 
        for idx_TXSTA = 1:numTXSTAs %every STA from AP        

            for idx_LINK = 1:numBSS %every other AP

                switch simulation.PathlossModel

                    case 'TGax'            
                        all_pathloss{idx_AP,idx_TXSTA,idx_LINK} = pathloss_tgax_STA_AP(idx_AP,idx_TXSTA,idx_LINK,all_paths,simulation);

                    case 'EtaPowerLaw'            
                        all_pathloss{idx_AP,idx_TXSTA,idx_LINK} = pathloss_etaPL_STA_AP(idx_AP,idx_TXSTA,idx_LINK,all_paths,simulation);

                    case 'Other'            
                        all_pathloss{idx_AP,idx_TXSTA,idx_LINK} = pathloss_etaPL_STA_AP(idx_AP,idx_TXSTA,idx_LINK,all_paths,simulation);

                end

            end
        
        end
        
    end

end

% **********************************************************************************************************************
% this function calculates all PL between APs and STAs
function [all_pathloss] = all_pathloss_AP_STA(all_bss, all_paths, simulation)
numBSS = numel(all_bss);
all_pathloss= [];

% for every AP to STA find the pathloss along given simulation model
    for idx_AP = 1:numBSS %every AP
        for idx_LINK = 1:numBSS %every LINK with STAs
            numSTAs = size(all_bss{idx_LINK}.STAs_pos,1);
            for idx_STA = 1:numSTAs %every STA from LINK
            
                switch simulation.PathlossModel

                    case 'TGax'            
                        all_pathloss{idx_AP,idx_LINK,idx_STA} = pathloss_tgax_STA(idx_AP,idx_LINK,idx_STA,all_paths,simulation);

                    case 'EtaPowerLaw'            
                        all_pathloss{idx_AP,idx_LINK,idx_STA} = pathloss_etaPL_STA(idx_AP,idx_LINK,idx_STA,all_paths,simulation);

                    case 'Other'            
                        all_pathloss{idx_AP,idx_LINK,idx_STA} = pathloss_etaPL_STA(idx_AP,idx_LINK,idx_STA,all_paths,simulation);

                end           
                
            end
        end
    end
end

% **********************************************************************************************************************
% this function calculates all PL between STAs and STAs
function [all_pathloss] = all_pathloss_STA_STA(all_bss, all_paths, simulation)
numBSS = numel(all_bss);
all_pathloss= [];

% for every STA to STA find the pathloss along given simulation model
    for idx_AP = 1:numBSS %every AP
        
        numTXSTAs = size(all_bss{idx_AP}.STAs_pos,1); 
        for idx_TXSTA = 1:numTXSTAs %every STA from AP        
        
            for idx_LINK = 1:numBSS %every LINK with STAs
                
                numSTAs = size(all_bss{idx_LINK}.STAs_pos,1);
                for idx_STA = 1:numSTAs %every STA from LINK

                    switch simulation.PathlossModel

                        case 'TGax'            
                            all_pathloss{idx_AP,idx_TXSTA,idx_LINK,idx_STA} = pathloss_tgax_STA_STA(idx_AP,idx_TXSTA,idx_LINK,idx_STA,all_paths,simulation);

                        case 'EtaPowerLaw'            
                            all_pathloss{idx_AP,idx_TXSTA,idx_LINK,idx_STA} = pathloss_etaPL_STA_STA(idx_AP,idx_TXSTA,idx_LINK,idx_STA,all_paths,simulation);

                        case 'Other'            
                            all_pathloss{idx_AP,idx_TXSTA,idx_LINK,idx_STA} = pathloss_etaPL_STA_STA(idx_AP,idx_TXSTA,idx_LINK,idx_STA,all_paths,simulation);

                    end           

                end
            end
            
        end        
        
    end

end
% **********************************************************************************************************************
function [] = clearLineValues()
    
    h_path_floors.String = '';
    h_path_walls.String = '';
    h_path_distance.String = '';
    h_path_PL.String = '';

    % delete old line
    delete(findobj('tag', 'path_line'));
        
end
% **********************************************************************************************************************% **********************************************************************************************************************
function [] = plotAP_AP()
    
    % AP to AP
    idxAP = h_path_ap_tx_popup.Value - 1;
    idxBSS = h_path_ap_rx_popup.Value - 1;
    floor_cnt = all_path_AP_DL{idxAP,idxBSS}.floors;
    wall_cnt = all_path_AP_DL{idxAP,idxBSS}.walls;
    distance = all_path_AP_DL{idxAP,idxBSS}.distance;
    pathloss = all_pathloss_AP_DL{idxAP,idxBSS};

    h_path_floors.String = num2str(floor_cnt);
    h_path_walls.String = num2str(wall_cnt);
    h_path_distance.String = num2str(distance);
    h_path_PL.String = num2str(pathloss,'%.2f');

    % delete old line and draw the line of path
    hold on
    delete(findobj('tag', 'path_line'));
    P0 = all_bss{idxAP}.AP_pos;
    P1 = all_bss{idxBSS}.AP_pos;
    x_tmp = [P0(1);P1(1)];
    y_tmp = [P0(2);P1(2)];
    z_tmp = [P0(3);P1(3)];
    line(h_axes_space, x_tmp, y_tmp, z_tmp,'tag', 'path_line','Color','r');         
    hold off
        
end
% **********************************************************************************************************************% **********************************************************************************************************************
function [] = plotAP_STA()
    
    % AP to STA
    idxAP = h_path_ap_tx_popup.Value - 1;
    idxBSS = h_path_ap_rx_popup.Value - 1;
    idxSTA = h_path_sta_rx_popup.Value - 1;
    floor_cnt = all_path_STA_DL{idxAP,idxBSS,idxSTA}.floors;
    wall_cnt = all_path_STA_DL{idxAP,idxBSS,idxSTA}.walls;
    distance = all_path_STA_DL{idxAP,idxBSS,idxSTA}.distance;
    pathloss = all_pathloss_STA_DL{idxAP,idxBSS,idxSTA};

    h_path_floors.String = num2str(floor_cnt);
    h_path_walls.String = num2str(wall_cnt);
    h_path_distance.String = num2str(distance);
    h_path_PL.String = num2str(pathloss,'%.2f');

    % delete old line and draw the line of path
    hold on
    delete(findobj('tag', 'path_line'));
    P0 = all_bss{idxAP}.AP_pos;
    P1 = all_bss{idxBSS}.STAs_pos(idxSTA,:);
    x_tmp = [P0(1);P1(1)];
    y_tmp = [P0(2);P1(2)];
    z_tmp = [P0(3);P1(3)];
    line(h_axes_space, x_tmp, y_tmp, z_tmp,'tag', 'path_line','Color','r');         
    hold off
        
end
% **********************************************************************************************************************% **********************************************************************************************************************
function [] = plotSTA_STA()
    
    % STA to STA
    idxAP = h_path_ap_tx_popup.Value - 1;
    idxBSS = h_path_ap_rx_popup.Value - 1;
    idxTXSTA = h_path_sta_tx_popup.Value - 1;
    idxSTA = h_path_sta_rx_popup.Value - 1;
    floor_cnt = all_path_STA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.floors;
    wall_cnt = all_path_STA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.walls;
    distance = all_path_STA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.distance;
    pathloss = all_pathloss_STA_UL{idxAP,idxTXSTA,idxBSS,idxSTA};

    h_path_floors.String = num2str(floor_cnt);
    h_path_walls.String = num2str(wall_cnt);
    h_path_distance.String = num2str(distance);
    h_path_PL.String = num2str(pathloss,'%.2f');

    % delete old line and draw the line of path
    hold on
    delete(findobj('tag', 'path_line'));
    P0 = all_bss{idxAP}.STAs_pos(idxTXSTA,:);
    P1 = all_bss{idxBSS}.STAs_pos(idxSTA,:);
    x_tmp = [P0(1);P1(1)];
    y_tmp = [P0(2);P1(2)];
    z_tmp = [P0(3);P1(3)];
    line(h_axes_space, x_tmp, y_tmp, z_tmp,'tag', 'path_line','Color','r');         
    hold off
        
end% **********************************************************************************************************************% **********************************************************************************************************************
function [] = plotSTA_AP()
    
    % STA to STA
    idxAP = h_path_ap_tx_popup.Value - 1;
    idxBSS = h_path_ap_rx_popup.Value - 1;
    idxTXSTA = h_path_sta_tx_popup.Value - 1;
    floor_cnt = all_path_AP_UL{idxAP,idxTXSTA,idxBSS}.floors;
    wall_cnt = all_path_AP_UL{idxAP,idxTXSTA,idxBSS}.walls;
    distance = all_path_AP_UL{idxAP,idxTXSTA,idxBSS}.distance;
    pathloss = all_pathloss_AP_UL{idxAP,idxTXSTA,idxBSS};

    h_path_floors.String = num2str(floor_cnt);
    h_path_walls.String = num2str(wall_cnt);
    h_path_distance.String = num2str(distance);
    h_path_PL.String = num2str(pathloss,'%.2f');

    % delete old line and draw the line of path
    hold on
    delete(findobj('tag', 'path_line'));
    P0 = all_bss{idxAP}.STAs_pos(idxTXSTA,:);
    P1 = all_bss{idxBSS}.AP_pos;
    x_tmp = [P0(1);P1(1)];
    y_tmp = [P0(2);P1(2)];
    z_tmp = [P0(3);P1(3)];
    line(h_axes_space, x_tmp, y_tmp, z_tmp,'tag', 'path_line','Color','r');         
    hold off
        
end
% **********************************************************************************************************************
function [rc,reason] = CheckConfiguration(all_bss,simulation)
    
    noBSS = false;
    multiBSS = false;
    multiSTA = false;
    multiANT = false;
    multiSTS = false;
    multiCH = false;
    MCSover7 = false;
    PLover2304 = false;
    nonIntnegLoc = false;
    mixedMIMO = false;
    mixedTXRX = false;
    beamforming = false;
    expandMIMO = false;
    W2LOS = false;
    PHYnotax = false;
    CHnotW2 = false;
    numBSSNEnumTXRX = false;
    numTXNEnumSTS = false;
    gt2RXAnt = false;
    rc = 0;
    reason = '';
    
    numBSS = numel(all_bss);
    if numBSS < 1
        noBSS = true;
    end
    if numBSS > 1
        multiBSS = true;
    end
    
    % check for beamforming
    if (simulation.BEAMFORMING == true) || (simulation.A.BEAMFORMING == true) || (simulation.B.BEAMFORMING == true)
        beamforming = true;
    end
    
    % loop through all BSS to identify multiSTA or multiANT situations or mixed MIMO
    for idxBSS = 1:numBSS               
        numSTA = size(all_bss{idxBSS}.STAs_pos,1);        
        tempTX = all_bss{idxBSS}.num_tx;
        tempRX = all_bss{idxBSS}.num_rx;
        
        % number of RX antennas greaten than 2
        if tempRX > 2
            gt2RXAnt = true;
        end
        
        % number of BSS not equal to number of TX/RX antennas
        if (numBSS ~= tempTX) || (numBSS ~= tempRX)
            numBSSNEnumTXRX = true;
        end

        % multiAnt
        if (all_bss{idxBSS}.num_tx > 1) || (all_bss{idxBSS}.num_rx > 1)
            multiANT = true;
        end
        
        % multiSTA
        if numSTA > 1
            multiSTA = true;
        end
        
        for idxSTA = 1:numSTA
            
            tempSTS = all_bss{idxBSS}.STAs_sts(idxSTA);
            % mixed MIMO
            if (tempTX ~= tempRX) || (tempTX ~= tempSTS)
                mixedMIMO = true;
            end
            
            % num TX not equal STS
            if tempTX ~= tempSTS 
                numTXNEnumSTS = true;
            end
            
            % mixed TXRX
            if (tempTX ~= tempRX)
                mixedTXRX = true;
            end
            
            % spatial expansion cases supported
            if (tempTX == tempRX) || (tempTX == tempSTS)
                % direct expansion, ok
            else
                if tempSTS == 1
                    if (tempTX == 1)||(tempTX == 2)||(tempTX == 4)||(tempTX == 8)
                        % ok
                    else
                        expandMIMO = true;
                    end
                elseif (tempSTS == 2) && (tempRX >= 2)
                    if (tempTX == 2)||(tempTX == 4)||(tempTX == 8)
                        % ok
                    else
                        expandMIMO = true;
                    end
                elseif tempSTS == 4 && (tempRX >= 4)
                    if (tempTX == 4)||(tempTX == 8)
                        % ok
                    else
                        expandMIMO = true;
                    end
                else
                    expandMIMO = true;
                end
            end
            
            % multiSTS
            if all_bss{idxBSS}.STAs_sts(idxSTA) > 1
                multiSTS = true;
            end           
            
            % MCSover8
            if all_bss{idxBSS}.STAs_mcs(idxSTA) > 7
                MCSover7 = true;
            end                      
            
            % PLover2304
            if all_bss{idxBSS}.STAs_apep(idxSTA) > 2304
                PLover2304 = true;
            end                      
        end       
        
    end
    
    % loop through all BSS to identify noninteger, negative location coordinates (see WINNER II)
    for idxBSS = 1:numBSS               
        numSTA = size(all_bss{idxBSS}.STAs_pos,1);       
        
       % AP 
        x_tmp = all_bss{idxBSS}.AP_pos(1);
        y_tmp = all_bss{idxBSS}.AP_pos(2);
        z_tmp = all_bss{idxBSS}.AP_pos(3);

        % negative value or noninteger
        if x_tmp < 0 || y_tmp < 0 || z_tmp < 0
            nonIntnegLoc = true;
        end
        
        if  floor(x_tmp)~= x_tmp || floor(y_tmp)~= y_tmp || floor(z_tmp)~= z_tmp
            nonIntnegLoc = true;
        end           

        for idxSTA = 1:numSTA
            
            %STAs
            x_tmp = all_bss{idxBSS}.STAs_pos(idxSTA,1);
            y_tmp = all_bss{idxBSS}.STAs_pos(idxSTA,2);
            z_tmp = all_bss{idxBSS}.STAs_pos(idxSTA,3);
 
            % negative value or noninteger
            if x_tmp < 0 || y_tmp < 0 || z_tmp < 0
                nonIntnegLoc = true;
            end           

            if  floor(x_tmp)~= x_tmp || floor(y_tmp)~= y_tmp || floor(z_tmp)~= z_tmp
                nonIntnegLoc = true;
            end           

        end           
    end
    
    % check if muliple channels are used
    if noBSS == false
        for idxBSS = 2:numBSS
            if all_bss{idxBSS}.ch ~= all_bss{1}.ch
                multiCH = true;
            end
        end    
    end
    
    % check for LOS/NLOS with winner 2
    switch simulation.w2PropCondition
        case 'LOS'
            W2LOS = true;
    end
    
    % check for PHY type 
    switch simulation.PHYType
        case 'IEEE 802.11n'
            PHYnotax = true;

        case 'IEEE 802.11a'
            PHYnotax = true;
    end
    
    % check for channel type 
    switch simulation.ChannelModel
        case 'TGax'
            CHnotW2 = true;

        case 'None'
            CHnotW2 = true;
    end
        
    % check if conditions lead to error: General
    if noBSS == true
        rc = 1;
        reason = 'No BSS defined!';
        return;
    end
    
    if PLover2304 == true
        rc = 1;
        reason = 'Payload size without aggregation greater than 2304 bytes';
        return;
    end
    
    % check if conditions lead to error: WINNER II negative or non-integer locations
    switch simulation.ChannelModel
        case 'WINNER II'
            
            if nonIntnegLoc == true
                rc = 1;
                reason = 'Negative or non-integer locations not supported by WINNER II model';
                return;
            end
            
        case 'TGax'
            
        case 'None'
    end

    % check if conditions lead to error: TGax and WINNER II MIMO setup
    switch simulation.ChannelModel
        case 'WINNER II'
            
            if expandMIMO == true
                rc = 1;
                reason = '#TX/#RX#/STS MIMO combination not supported with WINNER II channel model';
                return;
            end
            
        case 'TGax'
            
            if mixedMIMO == true
                rc = 1;
                reason = '#TX not equal #RX not equal #STS MIMO not supported for TGax channel model';
                return;
            end
            
            if beamforming == true
                rc = 1;
                reason = 'Beamforming not supported for TGax channel model';
                return;
            end
            
        case 'None'
    end

    % check if conditions lead to error: PHY
    
    switch simulation.PHYType

        case 'IEEE 802.11ax'
    
        case 'IEEE 802.11n'
            if MCSover7 == true
                rc = 1;
                reason = 'MCS higher than MCS 7 not supported for IEEE 802.11n';
                return;
            end
            if multiSTS == true
                rc = 1;
                reason = 'MCS higher than MCS 7 (multi STS) not supported for IEEE 802.11n';
                return;
            end
            
    
        case 'IEEE 802.11a'
            if MCSover7 == true
                rc = 1;
                reason = 'MCS higher than MCS 7 not supported for IEEE 802.11a';
                return;
            end
            
            if multiSTS == true
                rc = 1;
                reason = 'MultiSTS not supported for IEEE 802.11a';
                return;
            end
            
    end

    % check if conditions lead to error: SIMULATION
    
    str = h_simu_popup.String;
    val = h_simu_popup.Value;
    switch str{val}

        case 'CompareA2B'

            simulation.typeA = string(h_A2B_popupA.String{h_A2B_popupA.Value});
            strA = h_A2B_popupA.String;
            valA = h_A2B_popupA.Value;
            switch strA{valA}

                case 'CSMA/CA'
                    if (multiSTA == true) || (multiANT == true) || (multiSTS == true)
%                         rc = 1;
%                         reason = 'MCS higher than MCS 7 not supported for PHY type';
%                         return;
                    end
                   
                case 'CSMA/SDMSR'
                    if numTXNEnumSTS == true
                        rc = 1;
                        reason = 'Number of TX antennas has to be equal to number of STS for CSMA/SDMSR';
                        return;
                    end
                    
                    if W2LOS == true
                        rc = 1;
                        reason = 'LOS not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if PHYnotax == true
                        rc = 1;
                        reason = 'PHY other than IEEE 802.11ax not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if CHnotW2 == true
                        rc = 1;
                        reason = 'Channel other than Winner 2 not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if gt2RXAnt == true
                        rc = 1;
                        reason = 'More than 2 RX antennas not implemented for CSMA/SDMSR';
                        return;
                    end

                    if multiSTA == true
                        rc = 1;
                        reason = 'More than 1 STA per BSS not supported for CSMA/SDMSR';
                        return;
                    end             
                    
%                     if multiSTS == true
%                         rc = 1;
%                         reason = 'More than 1 STS per link not supported for CSMA/SDMSR';
%                         return;
%                     end             
                    
%                     if numBSSNEnumTXRX == true
%                         rc = 1;
%                         reason = 'Number BSS has to be equal to number of TX/RX antennas for CSMA/SDMSR';
%                         return;
%                     end
                    
                case 'CSMA/SR'
                    if numTXNEnumSTS == true
                        rc = 1;
                        reason = 'Number of TX antennas has to be equal to number of STS for CSMA/SR';
                        return;
                    end
                   
                    if W2LOS == true
                        rc = 1;
                        reason = 'LOS not supported for CSMA/SR';
                        return;
                    end
                    
                    if PHYnotax == true
                        rc = 1;
                        reason = 'PHY other than IEEE 802.11ax not supported for CSMA/SR';
                        return;
                    end
                    
                    if CHnotW2 == true
                        rc = 1;
                        reason = 'Channel other than Winner 2 not supported for CSMA/SR';
                        return;
                    end
                    
                    if multiSTA == true
                        rc = 1;
                        reason = 'More than 1 STA per BSS not supported for CSMA/SR';
                        return;
                    end
                    
                    %                     if multiSTS == true
%                         rc = 1;
%                         reason = 'More than 1 STS per link not supported for CSMA/SR';
%                         return;
%                     end             
                    
%                     if numBSSNEnumTXRX == true
%                         rc = 1;
%                         reason = 'Number BSS has to be equal to number of TX/RX antennas for CSMA/SR';
%                         return;
%                     end
                    
                case 'Other'

            end

            simulation.typeB = string(h_A2B_popupB.String{h_A2B_popupB.Value});
            strB = h_A2B_popupB.String;
            valB = h_A2B_popupB.Value;
            switch strB{valB}
                
                case 'CSMA/CA'
                    if (multiSTA == true) || (multiANT == true) || (multiSTS == true)
%                         rc = 1;
%                         reason = 'MCS higher than MCS 7 not supported for PHY type';
%                         return;
                    end

                case 'CSMA/SDMSR'
                    if numTXNEnumSTS == true
                        rc = 1;
                        reason = 'Number of TX antennas has to be equal to number of STS for CSMA/SDMSR';
                        return;
                    end

                    if W2LOS == true
                        rc = 1;
                        reason = 'LOS not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if PHYnotax == true
                        rc = 1;
                        reason = 'PHY other than IEEE 802.11ax not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if CHnotW2 == true
                        rc = 1;
                        reason = 'Channel other than Winner 2 not supported for CSMA/SDMSR';
                        return;
                    end
                    
                    if gt2RXAnt == true
                        rc = 1;
                        reason = 'More than 2 RX antennas not implemented for CSMA/SDMSR';
                        return;
                    end
                                        
                    if multiSTA == true
                        rc = 1;
                        reason = 'More than 1 STA per BSS not supported for CSMA/SDMSR';
                        return;
                    end             
                    
%                     if multiSTS == true
%                         rc = 1;
%                         reason = 'More than 1 STS per link not supported for CSMA/SDMSR';
%                         return;
%                     end                    
                    
%                     if numBSSNEnumTXRX == true
%                         rc = 1;
%                         reason = 'Number BSS has to be equal to number of TX/RX antennas for CSMA/SDMSR';
%                         return;
%                     end                    
                    
                case 'CSMA/SR'
                    if numTXNEnumSTS == true
                        rc = 1;
                        reason = 'Number of TX antennas has to be equal to number of STS for CSMA/SR';
                        return;
                    end
  
                    if W2LOS == true
                        rc = 1;
                        reason = 'LOS not supported for CSMA/SR';
                        return;
                    end
                    
                    if PHYnotax == true
                        rc = 1;
                        reason = 'PHY other than IEEE 802.11ax not supported for CSMA/SR';
                        return;
                    end
                    
                    if CHnotW2 == true
                        rc = 1;
                        reason = 'Channel other than Winner 2 not supported for CSMA/SR';
                        return;
                    end
                    
                    if multiSTA == true
                        rc = 1;
                        reason = 'More than 1 STA per BSS not supported for CSMA/SR';
                        return;
                    end             
                    
%                     if multiSTS == true
%                         rc = 1;
%                         reason = 'More than 1 STS per link not supported for CSMA/SR';
%                         return;
%                     end                    
                    
%                     if numBSSNEnumTXRX == true
%                         rc = 1;
%                         reason = 'Number BSS has to be equal to number of TX/RX antennas for CSMA/SR';
%                         return;
%                     end                    
                    
                case 'Other'
                
            end

    case 'LoopOver'
        
        str = h_LOOP_popup.String;
        val = h_LOOP_popup.Value;
        simulation.LoopPar = string(str{val});
        switch str{val}
            
            case 'PayloadLength'
             
            case 'MCS'
             
            case 'TransmitPower'
             
            case 'OBSS_PDLevel'
             
            case 'SNR'
                        
                % multi BSS for SNR loop
                if multiBSS == true
                    rc = 1;
                    reason = 'Muti BSS for SNR-Loop not supported!';
                    return;
                end
                
        end 
    
    end
    
end
% **********************************************************************************************************************


% **********************************************************************************************************************
% **********************************************************************************************************************
end % end GUI function