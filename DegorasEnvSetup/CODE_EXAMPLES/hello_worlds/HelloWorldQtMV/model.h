#pragma once

#include <QObject>

#include <QDebug>

class Model : public QObject
{
    Q_OBJECT
public:
    explicit Model(QObject *parent = nullptr);

public slots:

    void shortActionReq();

    void longActionReq();

signals:

    void var1TextChanged(const QString &text);
    void var2TextChanged(const QString &text);
    void statusTextChanged(const QString &text);

private:

    QString var1_;
    QString var2_;
};
