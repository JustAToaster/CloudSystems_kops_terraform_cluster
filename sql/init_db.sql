CREATE DATABASE yolov5_predictions;
CREATE TABLE yolov5_predictions.requests (UserAddress varchar(255),ImageName varchar(255), CustomizationScore float);
CREATE TABLE yolov5_predictions.users (UserAddress varchar(255), NumAccesses integer, TotalScore float);

CREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;

CREATE OR REPLACE FUNCTION check_user()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
DECLARE
    MaxAccesses constant integer := 20;
    ScoreThreshold constant float := 0.8;
BEGIN
    IF (NEW.NumAccesses > MaxAccesses AND (cast(NEW.TotalScore as float)/NEW.NumAccesses) > ScoreThreshold) THEN
        IF cardinality(TG_ARGV)!=2 THEN
        RAISE EXCEPTION 'Expected 2 parameters but got %', cardinality(TG_ARGV);
    ELSEIF TG_ARGV[0]='' THEN
        RAISE EXCEPTION 'Lambda function name is empty';
    ELSEIF TG_ARGV[1]='' THEN
        RAISE EXCEPTION 'Lambda function region is empty';
    ELSE
        PERFORM * FROM aws_lambda.invoke(aws_commons.create_lambda_function_arn(TG_ARGV[0], TG_ARGV[1]),
                                CONCAT('{"UserAddress": "', NEW.UserAddress,
                                        '", "reported_at": "', TO_CHAR(NOW()::timestamp, 'YYYY-MM-DD"T"HH24:MI:SS'), 
                                    '"}')::json,
                                        'Event');
            RETURN NEW;
        END IF;
    END IF;
END
$$;

CREATE OR REPLACE FUNCTION log_user_activity()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
    UPDATE yolov5_predictions.users SET (NumAccesses, TotalScore) = (NumAccesses+1, TotalScore+NEW.CustomizationScore) WHERE UserAddress = NEW.UserAddress;
END
$$;

CREATE TRIGGER trigger_requests_insert
  AFTER INSERT ON yolov5_predictions.requests
  FOR EACH ROW
  EXECUTE PROCEDURE log_user_activity();

CREATE TRIGGER trigger_users_update
  AFTER UPDATE ON yolov5_predictions.users
  FOR EACH ROW
  EXECUTE PROCEDURE check_user("update_reported_list", "us-east-1");