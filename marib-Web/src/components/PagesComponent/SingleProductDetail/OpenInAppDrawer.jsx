'use client'
import { t } from '@/utils';
import { Button, Drawer, Space } from 'antd'
import { usePathname } from 'next/navigation';
import React from 'react'

const OpenInAppDrawer = ({ IsOpenInApp, OnHide, systemSettingsData }) => {

    const path = usePathname()

    const companyName = systemSettingsData?.data?.data?.company_name

    const primaryColor = getComputedStyle(document.documentElement).getPropertyValue('--primary-color');


    function openInApp() {

        var sanitizedCompanyName = companyName.trim().toLowerCase().replace(/\s+/g, '-');
        var appScheme = `${sanitizedCompanyName}://${window.location.hostname}${path}`;
        var androidAppStoreLink = systemSettingsData?.data?.data?.play_store_link;
        var iosAppStoreLink = systemSettingsData?.data?.data?.app_store_link;
        var userAgent = navigator.userAgent || navigator.vendor || window.opera;
        var isAndroid = /android/i.test(userAgent);
        var isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;
        var appStoreLink = isAndroid ? androidAppStoreLink : (isIOS ? iosAppStoreLink : androidAppStoreLink);
        // Attempt to open the app
        window.location.href = appScheme;
        // Set a timeout to check if app opened
        setTimeout(function () {
            if (document.hidden || document.webkitHidden) {
                // App opened successfully
            } else {
                // App is not installed, ask user if they want to go to app store
                if (confirm("eClassify app is not installed. Would you like to download it from the app store?")) {
                    window.location.href = appStoreLink;
                }
            }
        }, 1000);
    }

    return (

        <Drawer
            title={`${t('viewIn')} ${companyName} ${t('app')}`}
            placement='bottom'
            width={500}
            onClose={OnHide}
            open={IsOpenInApp}
            styles={{
                body: { display: 'none' },
                wrapper: { height: 'auto', borderRadius: '150px' },
                content: { borderTopLeftRadius: '15px', borderTopRightRadius: '15px' }
            }}
            extra={
                <Space>
                    <Button style={{ backgroundColor: primaryColor, color: 'white' }} onClick={openInApp}>
                        {t('open')}
                    </Button>
                </Space>
            }
            maskClosable={false}
        >
        </Drawer>
    )
}

export default OpenInAppDrawer