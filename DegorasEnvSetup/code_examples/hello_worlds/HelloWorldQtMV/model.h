#pragma once

#include <atomic>

#include <QObject>

#include <QDebug>

class Model : public QObject
{
    Q_OBJECT
	
public:

    explicit Model(QObject *parent = nullptr);
	
	~Model();

public slots:

    void shortActionReq();

    void longActionReq();
	
    void requestStop() noexcept;
	
signals:

    void var1TextChanged(const QString &text);
    void var2TextChanged(const QString &text);
    void statusTextChanged(const QString &text);

private:

    bool shouldStop() const noexcept;

    QString var1_;
    QString var2_;
	std::atomic_bool stop_req_;
};
