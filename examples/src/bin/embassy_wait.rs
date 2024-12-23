//! embassy wait
//!
//! This is an example of asynchronously `Wait`ing for a pin state (boot button) to change.

//% CHIPS: esp32 esp32c2 esp32c3 esp32c6 esp32h2 esp32s2 esp32s3
//% FEATURES: embassy embassy-generic-timers

#![no_std]
#![no_main]

use embassy_executor::Spawner;
use embassy_time::{Duration, Timer};
use esp_backtrace as _;
use esp_hal::{
    gpio::{Input, Pull},
    timer::timg::TimerGroup,
};

#[esp_hal_embassy::main]
async fn main(_spawner: Spawner) {
    esp_println::println!("Init!");
    let peripherals = esp_hal::init(esp_hal::Config::default());

    let timg0 = TimerGroup::new(peripherals.TIMG0);
    esp_hal_embassy::init(timg0.timer0);

    cfg_if::cfg_if! {
        if #[cfg(any(feature = "esp32", feature = "esp32s2", feature = "esp32s3"))] {
            let mut input = Input::new(peripherals.GPIO0, Pull::Down);
        } else {
            let mut input = Input::new(peripherals.GPIO9, Pull::Down);
        }
    }

    loop {
        esp_println::println!("Waiting...");
        input.wait_for_rising_edge().await;
        esp_println::println!("Ping!");
        Timer::after(Duration::from_millis(100)).await;
    }
}
