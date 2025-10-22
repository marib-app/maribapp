"use client"
import PushNotificationLayout from '@/components/firebaseNotification/PushNotificationLayout';
import React, { useEffect, useState } from 'react';
import Chat from './Chat';
import { useSelector } from 'react-redux';

const Messages = () => {

    const [activeTab, setActiveTab] = useState('buying')
    const [chatMessages, setChatMessages] = useState([]);
    const [notificationData, setNotificationData] = useState([]);
    const ChatOfferData = useSelector((state) => state?.OfferData)
    const defaultSelected = ChatOfferData?.data ? ChatOfferData?.data : "";
    const [selectedTabData, setSelectedTabData] = useState(defaultSelected ? defaultSelected : null);

    const handleNotificationReceived = (data) => {
        setNotificationData(data);
    };

    useEffect(() => { }, [notificationData]);

    return (
        <PushNotificationLayout onNotificationReceived={handleNotificationReceived} setActiveTab={setActiveTab} setChatMessages={setChatMessages} selectedTabData={selectedTabData} setSelectedTabData={setSelectedTabData} defaultSelected={defaultSelected}>
            <Chat activeTab={activeTab} setActiveTab={setActiveTab} chatMessages={chatMessages} setChatMessages={setChatMessages} selectedTabData={selectedTabData} setSelectedTabData={setSelectedTabData} defaultSelected={defaultSelected} />
        </PushNotificationLayout>
    );
}

export default Messages;
