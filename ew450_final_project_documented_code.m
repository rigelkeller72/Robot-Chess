% EW450 Final Project
% Lenny Davis and Rigel Keller
% ScorBot Chess
% TO DO:

%% Global Variables and
global ztable board_width board_x_offset board_xyz_coor board_y_grave

ztable = 120; %Height to place gripper off the table when grabbing pieces
board_width = 254; %Used to calculate
board_x_offset = 137; %How far the chessboard is from the ScorBot in XYZPR 
board_xyz_coor = board_XYZcoor_creator(ztable,board_x_offset); %Create an 8x8x5 array containing XYZPR coordinates for every place on the chessboard
board_y_grave = 170; %Y position for the ScorBot to drop pieces when making attacking moves

%% Move ScorBot to starting position
ScorAway = [50, 300, 300, -pi/2, 0]; %Move the ScorBot out of the way 
ScorSetXYZPR(ScorAway);
ScorWaitForMove; 



%% Calibrate Camera
clear camObj; %Initiate camera
[camObj,camPreview] = initCamera;

Im_calibration = getsnapshot(camObj);

%Identify red square
red_bw = BW_redsquare1(Im_calibration);
red_bw = bwareaopen(red_bw, 30);
red_bw = bwselect(red_bw)
figure; imshow(red_bw);

%Identify green square
green_bw = BW_greensquare1(Im_calibration);
green_bw = bwareaopen(green_bw, 100);
green_bw = bwselect(green_bw)
figure; imshow(green_bw);

%Identify pink square
pink_bw = BW_pinksquare1(Im_calibration);
pink_bw = bwareaopen(pink_bw, 80);
pink_bw = bwselect(pink_bw)
figure; imshow(pink_bw);

%Create conversion matrix using the known positions of the calibration
%squares
[M00, M01, M10, M11, M20, M02] = imageMoments(red_bw);
[row_c, col_c, phi, H1, H2] = objectProperties(M00, M01, M10, M11, M20, M02);
red_centriod = [row_c, col_c]
[M00, M01, M10, M11, M20, M02] = imageMoments(green_bw);
[row_c, col_c, phi, H1, H2] = objectProperties(M00, M01, M10, M11, M20, M02);
green_centriod = [row_c, col_c]
[M00, M01, M10, M11, M20, M02] = imageMoments(pink_bw);
[row_c, col_c, phi, H1, H2] = objectProperties(M00, M01, M10, M11, M20, M02);
pink_centriod = [row_c, col_c]
P_Matrix = [red_centriod, 1; green_centriod, 1; pink_centriod, 1]';

red_base = [402.1190  131.0940]
pink_base = [402.1190  -131.0940]
green_base = [130.1430 -121.1150]
P_Base = [red_base, 1; green_base, 1; pink_base, 1]'

A_Base2Matrix = P_Matrix * pinv(P_Base);
A_Matrix2Base = P_Base * pinv(P_Matrix);

%% Start game
fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'; %Set starting fen for the beginning of a chess game
checkmate = 0; %Initalize flag for checkmate 
while ~checkmate % Continue the game until there is a chechmate
    
    legal = 0; %Initalize flag for legal move
    while ~legal
        %% Get Snapshot Before User Movement
        Im_1_rgb = getsnapshot(camObj);
        BW_1 = BW_chess_pieces(Im_1_rgb) + BW_orange_pieces(Im_1_rgb);
        
        %%
        max_frame = 0;
        while max_frame < 2000
            fprintf('Move your piece\n\r')
            pause(2);
            no_move_frames = 0;
            Im_2 = getsnapshot(camObj); 
            Im_2 = move_BW(Im_2);
            while no_move_frames < 20; 
                Im_1 = getsnapshot(camObj); 
                Im_1 = move_BW(Im_1);
                differ_frame = Im_1 - Im_2; 
                if sum(sum(differ_frame)) > 2000
                    no_move_frames = 0; 
                end
                if sum(sum(differ_frame))> max_frame
                    max_frame = sum(sum(differ_frame));
                end
                no_move_frames = no_move_frames + 1;
                Im_2 = Im_1;
                pause(.25); 
            end
        end
        %% Get Snapshot After User Movement
        Im_2_rgb = getsnapshot(camObj);
        BW_2 = BW_chess_pieces(Im_2_rgb) + BW_orange_pieces(Im_2_rgb);
       
        %% Determine centriod of user to and from in the matrix frame
        BW_differ = BW_1 - BW_2; %When doing this subtraction the from will be positive, to will be negative
    
        BW_from_indx = BW_differ > 0; %Seperate the to and from BW images
        BW_to_indx = BW_differ < -0;

        BW_from = logical(BW_from_indx);
        BW_to = logical(BW_to_indx); 
        BW_from = bwareaopen(BW_from,300);
        BW_to = bwareaopen(BW_to,300);
        
        [M00_f, M01_f, M10_f, M11_f, M20_f, M02_f] = imageMoments(BW_from);  %Find the matrix centriod of from
        [row_c_f, col_c_f, phi_f, H1_f, H2_f] = objectProperties(M00_f, M01_f, M10_f, M11_f, M20_f, M02_f);
          
        [M00_t, M01_t, M10_t, M11_t, M20_t, M02_t] = imageMoments(BW_to); %Find the matrix centriod of to
        [row_c_t, col_c_t, phi_t, H1_t, H2_t] = objectProperties(M00_t, M01_t, M10_t, M11_t, M20_t, M02_t);
        
        user_from_matrix = [row_c_f, col_c_f, 1]'; %Centriod of the user_from move in the matrix frame
        user_to_matrix = [row_c_t, col_c_t, 1]'; %Centriod of the user_to move in the base frame
        %% Convert centriods in matrix frame to centriods in the base frame
        %Using the Matrix 2 Base conversion
        user_from_base = A_Matrix2Base * user_from_matrix;
        user_to_base = A_Matrix2Base * user_to_matrix;
        
        %% Determine what square the pieces moved to/from
        user_from_rc = what_square(user_from_base);
        user_to_rc = what_square(user_to_base);
        
        if user_to_rc(1) == 0 %The what_square function has a special circumstance where it will return a position of (0,0) if a piece is moved to the graveyard. IE a user atttacking move. 
            user_to_string = input('What piece did you remove?', 's')
            user_to_rc = board2rc_half(user_to_string);
        end
        
        %% Send movement to Chess Engine
        user_move_string = rc2board(user_to_rc, user_from_rc)        
        ai_move = py.chess_functions_classroomV1.return_ai_move(user_move_string,fen);
        legal = double(ai_move.legal);
        if ~legal %The chess engine is able to return if a movement is legal. If the movement is not legal the user will be propted to move the piece back to where it was found and the process begins again
            fprintf('Movement was not legal, press enter when you have moved the piece back \n\r');
            pause();  
        else %If the movement is legal then the loop will procede and the fen will be updated. 
            fen = char(ai_move.board);
            checkmate = ai_move.checkmate;
            capture = ai_move.capture;
        end
        
    end
    fprintf('Move was legal, proceeding with ScorBot movement\n\r');
    %% Convert AI movement to ScorBot movement
    ai_move_string = char(ai_move.move.move) %Extract the board movement the Scorbot would like to make
    [ai_from_rc, ai_to_rc] = board2rc(ai_move_string); %Conver the board movement to row/column movements
    
    XYZPR_to = rc2base(ai_to_rc); %Convert the row/column movements to base frame movements (XYZPR)
    XYZPR_from = rc2base(ai_from_rc);
    
    if capture %If the AI wants to make a capture movement
        ScorChessRemove(XYZPR_to); %Remove the desired user piece 
    end
    
    ScorChessMove(XYZPR_to, XYZPR_from); %ScorBot/AI movement
end
ScorDestroy; %When the ScorBot wins, the board will promptly be dumped on the ground. 