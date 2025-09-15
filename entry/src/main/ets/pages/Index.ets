import { geoLocationManager } from '@kit.LocationKit';
import grantPermission from '../Utils/PermissionUtils';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import vibrator from '@ohos.vibrator';
import { map } from '@kit.MapKit';

let prevLatitude: number | null = null;
let prevLongitude: number | null = null;
let intervalId: number | undefined;
const LOCATION_CHECK_INTERVAL = 30000;

async function startManualLocationTracking() {
  try {
    await grantPermission();
  } catch (err) {
    console.info(`grantPermission failed  ${JSON.stringify(err)}`);
    return;
  }

  intervalId = setInterval(async () => {
    try {
      let location = await geoLocationManager.getCurrentLocation();
      if (prevLatitude !== null && prevLongitude !== null) {
        //add distance alarm if it is bigger then 400 m
        if (map.calculateDistance({ latitude: location.latitude, longitude: location.longitude },
          { latitude: prevLatitude, longitude: prevLongitude }) > 400) {
          try {
            // Start vibration.
            vibrator.startVibration({
              type: 'time',
              duration: 1000,
            }, {
              id: 0,
              usage: 'alarm'
            }, (error: BusinessError) => {
              if (error) {
                console.error(`Failed to start vibration. Code: ${error.code}, message: ${error.message}`);
                return;
              }
              console.info('Succeed in starting vibration');
            });
          } catch (err) {
            let e: BusinessError = err as BusinessError;
            console.error(`An unexpected error occurred. Code: ${e.code}, message: ${e.message}`);
          }
          console.info(`Location is changed! New Loc: lat=${location.latitude}, lon=${location.longitude}`);
        } else {
          console.info('Same Location');
        }
      } else {
        console.info(`First location lat=${location.latitude}, lon=${location.longitude}`);
      }

      prevLatitude = location.latitude;
      prevLongitude = location.longitude;
    } catch (err) {
      console.error(`Fail while getting location: ${JSON.stringify(err)}`);
    }
  }, LOCATION_CHECK_INTERVAL);
}

function stopManualLocationTracking() {
  if (intervalId !== undefined) {
    clearInterval(intervalId);
    intervalId = undefined;
    prevLatitude = null;
    prevLongitude = null;
    console.info('Stop location tracking.');
  }
}

@Entry
@Component
struct Index {
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  startContinuousTask() {
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgent) => {
      backgroundTaskManager.startBackgroundRunning(this.context, ['location'], wantAgent).then(() => {
        console.info('Continuous location task started');
        startManualLocationTracking();
      }).catch((err: BusinessError) => {
        console.error(`startBackgroundRunning failed: code=${err.code}, msg=${err.message}`);
      });
    }).catch((err: BusinessError) => {
      console.error(`getWantAgent failed: code=${err.code}, msg=${err.message}`);
    });
  }

  stopContinuousTask() {
    backgroundTaskManager.stopBackgroundRunning(this.context).then(() => {
      console.info('Continuous location task stopped');
      stopManualLocationTracking();
    }).catch((err: BusinessError) => {
      console.error(`stopBackgroundRunning failed: code=${err.code}, msg=${err.message}`);
    });
  }

  build() {
    Column() {
      Text('Your  Kid\'s Location')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 32, bottom: 32 })

      Button('Start Continuous Location Tracking')
        .onClick(() => {
          this.startContinuousTask();
        })
        .fontSize(12)
        .backgroundColor(Color.Red)
        .margin({ bottom: 20 })

      Button('Stop')
        .fontSize(12)
        .backgroundColor(Color.Red)
        .onClick(() => {
          this.stopContinuousTask();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}