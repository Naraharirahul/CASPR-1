% Class to store the configuration of different robots from the XML files
%
% Author        : Darwin LAU
% Created       : 2015
% Description    :
%    This class stores the locations for all of the different CDPRs that
%    are accessible within CASPR. The CDPR information is stored as XML
%    files. New robots that are added must also be added to the ModelConfig
%    in order for it to be accessible.
classdef ModelConfig   
    properties (SetAccess = private)
        type                        % Type of model from ModelConfigType enum
        bodyPropertiesFilename      % Filename for the body properties
        cablesPropertiesFilename    % Filename for the cable properties
        trajectoriesFilename        % Filename for the trajectories
        opFilename                  % Filename for the operational space
        
        bodiesModel                 % Stores the SystemModelBodies object for the robot model
        displayRange                % The axis range to display the robot
        defaultCableSetId           % ID for the default cable set to display first
    end
    
    properties (Access = private)
        root_folder                 % The root folder for the CASPR build
        
        bodiesXmlObj                % The DOMNode object for body props
        cablesXmlObj                % The DOMNode object for cable props
        trajectoriesXmlObj          % The DOMNode for trajectory props
        opXmlObj                    % The DOMNode for operational space
    end
    
    methods
        % Constructor for the ModelConfig class. This builds the xml
        % objects.
        function c = ModelConfig(type)
            c.type = type;
            c.root_folder = fileparts(mfilename('fullpath'));
            c.opFilename = '';
            c.opXmlObj = [];
            
            % Determine the Filenames
            type_string = char(type);
            % Open the master_list file
            fid = fopen([c.root_folder,'/master_list.csv']);
            % Load the contents
            cell_array = textscan(fid,'%s %s %s %s %s %s','delimiter',',');
            i_length = length(cell_array{1});
            status_flag = 1;
            % Loop through until the right line of the list is found
            for i = 1:i_length
                if(strcmp(char(cell_array{1}{i}),type_string))
                    cdpr_folder                 = char(cell_array{2}{i});
                    c.bodyPropertiesFilename    = [c.root_folder, cdpr_folder,char(cell_array{3}{i})];
                    c.cablesPropertiesFilename  = [c.root_folder, cdpr_folder,char(cell_array{4}{i})];
                    c.trajectoriesFilename      = [c.root_folder, cdpr_folder,char(cell_array{5}{i})];
                    if(~isempty(cell_array{6}{i}))
                        c.opFilename = [c.root_folder, cdpr_folder,char(cell_array{6}{i})];
                    end
                    fclose(fid);
                    status_flag = 0;
                    break;
                end
            end
            if(status_flag)
                error('ModelConfig type is not defined');
            end
                        
            % Make sure all the filenames that are required exist
            assert(exist(c.bodyPropertiesFilename, 'file') == 2, 'Body properties file does not exist.');
            assert(exist(c.cablesPropertiesFilename, 'file') == 2, 'Cable properties file does not exist.');
            assert(exist(c.trajectoriesFilename, 'file') == 2, 'Trajectories file does not exist.');
            % Read the XML file to an DOM XML object
            c.bodiesXmlObj =  XmlOperations.XmlReadRemoveIndents(c.bodyPropertiesFilename);
            c.cablesXmlObj =  XmlOperations.XmlReadRemoveIndents(c.cablesPropertiesFilename);
            c.trajectoriesXmlObj =  XmlOperations.XmlReadRemoveIndents(c.trajectoriesFilename);
            % If the operational space filename is specified then check and load it
            if (~isempty(c.opFilename))
                assert(exist(c.opFilename, 'file') == 2, 'Operational space properties file does not exist.');
                XmlOperations.XmlReadRemoveIndents(c.opFilename);
            end
            
            % Read the model config related properties from the bodies and
            % cables XML
            c.defaultCableSetId = char(c.cablesXmlObj.getDocumentElement.getAttribute('default_cable_set'));
            c.displayRange = XmlOperations.StringToVector(char(c.bodiesXmlObj.getDocumentElement.getAttribute('display_range')));
            % Loads the bodiesModel to be used for the trajectory loading
            bodies_xmlobj = c.getBodiesPropertiesXmlObj();
            cableset_xmlobj = c.getCableSetXmlObj(c.defaultCableSetId);
            sysModel = SystemModel.LoadXmlObj(bodies_xmlobj, cableset_xmlobj);
            c.bodiesModel = sysModel.bodyModel;
        end
                
        function [sysModel] = getModel(obj, cable_set_id, operational_space_id)
            bodies_xmlobj = obj.getBodiesPropertiesXmlObj();
            cableset_xmlobj = obj.getCableSetXmlObj(cable_set_id);
            sysModel = SystemModel.LoadXmlObj(bodies_xmlobj, cableset_xmlobj);
            
            if (nargin >= 3 && ~isempty(operational_space_id))
                op_xmlobj = obj.getOPXmlObj(op_set_id);
                sysModel.loadOpXmlObj(op_xmlobj);
            end
        end
        
        function [traj] = getTrajectory(obj, trajectory_id)
            traj_xmlobj = obj.getTrajectoryXmlObj(trajectory_id);
            traj = JointTrajectory.LoadXmlObj(traj_xmlobj, obj.bodiesModel);
        end
    end
    
    methods (Access = private)
        % Gets the body properties xml object
        function v = getBodiesPropertiesXmlObj(obj)
            v = obj.bodiesXmlObj.getDocumentElement;
        end
        
        % Gets the cable set properties xml object
        function v = getCableSetXmlObj(obj, id)
            v = obj.cablesXmlObj.getElementById(id);
            assert(~isempty(v), sprintf('Id ''%s'' does not exist in the cables XML file', id));
        end
        
        % Get the trajectory xml object
        function v = getTrajectoryXmlObj(obj, id)
            v = obj.trajectoriesXmlObj.getElementById(id);
            assert(~isempty(v), sprintf('Id ''%s'' does not exist in the trajectories XML file', id));
        end
        
        % Get the operational space xml object
        function v = getOPXmlObj(obj, id)
            v = obj.opXmlObj.getElementById(id);
            assert(~isempty(v), sprintf('Id ''%s'' does not exist in the operation XML file', id));
        end
    end
end

