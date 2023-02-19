CREATE SCHEMA yolov5_predictions;
CREATE TABLE yolov5_predictions.requests (RequestId SERIAL PRIMARY KEY, UserAddress varchar(255), ModelName varchar(255), ImageName varchar(255), CustomizationScore float);
CREATE TABLE yolov5_predictions.users (UserAddress varchar(255) PRIMARY KEY, NumAccesses integer, SuspiciousRequests integer, TotalScore float);

CREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;

CREATE OR REPLACE FUNCTION check_user()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
DECLARE
    MaxSuspiciousRequests constant integer := 10;
BEGIN
    IF (NEW.SuspiciousRequests > MaxSuspiciousRequests) THEN
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
    RETURN NULL;
END
$$;

CREATE OR REPLACE FUNCTION log_user_activity()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
DECLARE
    ScoreThreshold constant float := 0.7;
BEGIN
    INSERT INTO yolov5_predictions.users (UserAddress, NumAccesses, SuspiciousRequests, TotalScore) VALUES (NEW.UserAddress, 0, 0, 0.0) ON CONFLICT (UserAddress) DO NOTHING;
    UPDATE yolov5_predictions.users SET (NumAccesses, TotalScore) = (NumAccesses+1, TotalScore+NEW.CustomizationScore) WHERE yolov5_predictions.users.UserAddress = NEW.UserAddress;
    IF (NEW.CustomizationScore > ScoreThreshold) THEN
        UPDATE yolov5_predictions.users SET SuspiciousRequests = SuspiciousRequests+1 WHERE yolov5_predictions.users.UserAddress = NEW.UserAddress;
    END IF;
    RETURN NULL;
END
$$;

CREATE TRIGGER trigger_requests_insert
  AFTER INSERT ON yolov5_predictions.requests
  FOR EACH ROW
  EXECUTE PROCEDURE log_user_activity();

CREATE TRIGGER trigger_users_update
  AFTER UPDATE OF SuspiciousRequests ON yolov5_predictions.users
  FOR EACH ROW
  EXECUTE PROCEDURE check_user("update_reported_list", "us-east-1");